import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';

enum BookDownloadStatus { notDownloaded, downloading, downloaded, failed }

class BookDownloadState {
  const BookDownloadState({
    this.status = BookDownloadStatus.notDownloaded,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  final BookDownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  double? get progress =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0, 1) : null;
}

class DownloadService extends ChangeNotifier {
  DownloadService._();

  static final instance = DownloadService._();

  final Map<String, BookDownloadState> _states = {};
  final Map<String, HttpClient> _clients = {};
  final Set<String> _cancelled = {};

  BookDownloadState stateFor(String bookId) =>
      _states[bookId] ?? const BookDownloadState();

  Future<void> ensureState(Book book) async {
    if (stateFor(book.id).status == BookDownloadStatus.downloading) return;
    Book? local;
    try {
      local = await localBook(book);
    } catch (_) {
      local = null;
    }
    _setState(
      book.id,
      BookDownloadState(
        status: local == null
            ? BookDownloadStatus.notDownloaded
            : BookDownloadStatus.downloaded,
        downloadedBytes: local == null ? 0 : book.totalDownloadSize,
        totalBytes: book.totalDownloadSize,
      ),
    );
  }

  Future<Book?> localBook(Book book) async {
    final directory = await _bookDirectory(book.id);
    final pdf = File('${directory.path}/book.pdf');
    if (!await pdf.exists() || await pdf.length() == 0) return null;

    final audioPaths = <String>[];
    for (var index = 0; index < book.audio.length; index++) {
      final file = File(
        '${directory.path}/audio/${index.toString().padLeft(3, '0')}${_extension(book.audio[index].assetPath)}',
      );
      if (!await file.exists() || await file.length() == 0) return null;
      audioPaths.add(file.path);
    }
    return book.copyWithLocalMedia(pdfPath: pdf.path, audioPaths: audioPaths);
  }

  Future<void> download(Book book) async {
    if (stateFor(book.id).status == BookDownloadStatus.downloading) return;
    _cancelled.remove(book.id);
    final target = await _bookDirectory(book.id);
    final partial = Directory('${target.path}.partial');
    if (await partial.exists()) await partial.delete(recursive: true);
    await partial.create(recursive: true);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    _clients[book.id] = client;
    var received = 0;
    var lastNotified = 0;
    final total = book.totalDownloadSize;
    _setState(
      book.id,
      BookDownloadState(
        status: BookDownloadStatus.downloading,
        totalBytes: total,
      ),
    );

    void report(int bytes) {
      received += bytes;
      if (received - lastNotified < 64 * 1024 &&
          (total <= 0 || received < total)) {
        return;
      }
      lastNotified = received;
      _setState(
        book.id,
        BookDownloadState(
          status: BookDownloadStatus.downloading,
          downloadedBytes: received,
          totalBytes: total,
        ),
      );
    }

    try {
      await _downloadFile(
        client: client,
        bookId: book.id,
        source: book.pdfAsset,
        destination: File('${partial.path}/book.pdf'),
        onBytes: report,
      );
      final audioDirectory = Directory('${partial.path}/audio');
      if (book.audio.isNotEmpty) await audioDirectory.create(recursive: true);
      for (var index = 0; index < book.audio.length; index++) {
        final chapter = book.audio[index];
        await _downloadFile(
          client: client,
          bookId: book.id,
          source: chapter.assetPath,
          destination: File(
            '${audioDirectory.path}/${index.toString().padLeft(3, '0')}${_extension(chapter.assetPath)}',
          ),
          onBytes: report,
        );
      }
      if (_cancelled.contains(book.id)) throw const _DownloadCancelled();
      if (await target.exists()) await target.delete(recursive: true);
      await partial.rename(target.path);
      _setState(
        book.id,
        BookDownloadState(
          status: BookDownloadStatus.downloaded,
          downloadedBytes: total > 0 ? total : received,
          totalBytes: total > 0 ? total : received,
        ),
      );
    } on _DownloadCancelled {
      if (await partial.exists()) await partial.delete(recursive: true);
      _setState(book.id, const BookDownloadState());
    } catch (_) {
      if (await partial.exists()) await partial.delete(recursive: true);
      if (_cancelled.contains(book.id)) {
        _setState(book.id, const BookDownloadState());
      } else {
        _setState(
          book.id,
          BookDownloadState(
            status: BookDownloadStatus.failed,
            downloadedBytes: received,
            totalBytes: total,
            error: 'ޑައުންލޯޑު ނުކުރެވުނު',
          ),
        );
      }
    } finally {
      _clients.remove(book.id)?.close(force: true);
      _cancelled.remove(book.id);
    }
  }

  Future<void> cancel(String bookId) async {
    _cancelled.add(bookId);
    _clients.remove(bookId)?.close(force: true);
  }

  Future<void> remove(Book book) async {
    await cancel(book.id);
    final target = await _bookDirectory(book.id);
    final partial = Directory('${target.path}.partial');
    if (await target.exists()) await target.delete(recursive: true);
    if (await partial.exists()) await partial.delete(recursive: true);
    _setState(book.id, const BookDownloadState());
  }

  Future<void> _downloadFile({
    required HttpClient client,
    required String bookId,
    required String source,
    required File destination,
    required ValueChanged<int> onBytes,
  }) async {
    final uri = Uri.parse(source);
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw ArgumentError.value(source, 'source', 'Expected a remote URL');
    }
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Download failed (${response.statusCode})',
        uri: uri,
      );
    }
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    try {
      await for (final chunk in response) {
        if (_cancelled.contains(bookId)) throw const _DownloadCancelled();
        sink.add(chunk);
        onBytes(chunk.length);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<Directory> _bookDirectory(String bookId) async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/book_downloads');
    await root.create(recursive: true);
    final safeId = base64Url.encode(utf8.encode(bookId)).replaceAll('=', '');
    return Directory('${root.path}/$safeId');
  }

  String _extension(String source) {
    final segments = Uri.tryParse(source)?.pathSegments ?? const <String>[];
    final name = segments.isEmpty ? '' : segments.last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || name.length - dot > 6) return '.mp3';
    return name.substring(dot).toLowerCase();
  }

  void _setState(String bookId, BookDownloadState state) {
    _states[bookId] = state;
    notifyListeners();
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
