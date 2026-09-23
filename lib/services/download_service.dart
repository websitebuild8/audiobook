import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';

enum BookDownloadStatus { notDownloaded, downloading, downloaded, failed }

class BookDownloadState {
  const BookDownloadState(
      {this.status = BookDownloadStatus.notDownloaded,
      this.downloadedBytes = 0,
      this.totalBytes = 0,
      this.error});
  final BookDownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;
  double? get progress =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0, 1) : null;
}

/// Aggregates native task progress (PDF and chapters are tracked separately).
BookDownloadState aggregateDownloadState(List<TaskRecord> records, int count) {
  final complete = records.length == count &&
      records.every((r) => r.status == TaskStatus.complete);
  final active = records
      .any((r) => !r.status.isFinalState && r.status != TaskStatus.paused);
  final knownSizes =
      records.length == count && records.every((r) => r.expectedFileSize > 0);
  final total = knownSizes
      ? records.fold<int>(0, (s, r) => s + r.expectedFileSize)
      : count;
  final received = records.fold<int>(
      0,
      (s, r) =>
          s +
          (knownSizes
              ? (r.expectedFileSize *
                      (r.status == TaskStatus.complete
                          ? 1
                          : r.progress.clamp(0, 1)))
                  .round()
              : (r.status == TaskStatus.complete ? 1 : 0)));
  return BookDownloadState(
    status: complete
        ? BookDownloadStatus.downloaded
        : active
            ? BookDownloadStatus.downloading
            : BookDownloadStatus.failed,
    totalBytes: knownSizes ? total : 0,
    downloadedBytes: received,
  );
}

class DownloadService extends ChangeNotifier {
  DownloadService._()
      : _downloader = FileDownloader(),
        _rootOverride = null;

  @visibleForTesting
  DownloadService.forTesting(FileDownloader downloader, Directory directory)
      : _downloader = downloader,
        _rootOverride = directory;
  static final instance = DownloadService._();
  static const _group = 'book_files_v2';
  final FileDownloader _downloader;
  final Directory? _rootOverride;
  final Map<String, BookDownloadState> _states = {};
  final Map<String, BookDownloadState> _fileStates = {};
  final Map<String, List<DownloadTask>> _plans = {};
  final Map<String, TaskRecord> _records = {};
  final Map<String, Future<void>> _operations = {};
  Future<void>? _initializing;

  BookDownloadState stateFor(String id) =>
      _states[id] ?? const BookDownloadState();

  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object e) {
        _initializing = null;
        throw e;
      });

  Future<void> resumeUpdates() async {
    await initialize();
    await _downloader.resumeFromBackground();
  }

  Future<void> _initialize() async {
    final root = await _root();
    await for (final entry in root.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
        _plans[json['bookId'] as String] = (json['tasks'] as List)
            .map((t) =>
                DownloadTask.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList();
      } catch (_) {
        // A damaged manifest must not prevent the rest of the library opening.
      }
    }
    _downloader.registerCallbacks(
        group: _group,
        taskStatusCallback: (u) {
          final old = _records[u.task.taskId];
          _records[u.task.taskId] = TaskRecord(
              u.task,
              u.status,
              u.status == TaskStatus.complete ? 1 : old?.progress ?? 0,
              old?.expectedFileSize ?? -1);
          _refresh(u.task.metaData);
        },
        taskProgressCallback: (u) {
          final old = _records[u.task.taskId];
          _records[u.task.taskId] = TaskRecord(
              u.task,
              old?.status ?? TaskStatus.running,
              u.progress,
              u.expectedFileSize);
          _refresh(u.task.metaData);
        });
    await _downloader.start(doRescheduleKilledTasks: false);
    for (final r in await _downloader.database.allRecords(group: _group)) {
      _records.putIfAbsent(r.taskId, () => r);
    }
    for (final tasks in _plans.values) {
      for (final task in tasks) {
        final file = await _fileForTask(task);
        if (await file.exists() && await file.length() > 0) {
          _records[task.taskId] =
              TaskRecord(task, TaskStatus.complete, 1, await file.length());
        }
      }
    }
    final (_, failed) = await _downloader.rescheduleKilledTasks();
    for (final task in failed) {
      _records[task.taskId] = TaskRecord(task, TaskStatus.failed, 0, -1);
    }
    for (final id in _plans.keys) {
      _refresh(id);
    }
  }

  String _fileKey(String id, String filename) => '$id::$filename';
  String _audioFilename(Book book, int index) =>
      '${index.toString().padLeft(3, '0')}${_extension(book.audio[index].downloadSource)}';

  BookDownloadState chapterStateFor(Book book, int index) =>
      _fileStates[_fileKey(book.id, _audioFilename(book, index))] ??
      const BookDownloadState();

  void _refresh(String id) {
    final tasks = _plans[id];
    if (tasks == null || _operations.containsKey(id)) return;
    for (final task in tasks) {
      final record = _records[task.taskId];
      final state = aggregateDownloadState([if (record != null) record], 1);
      _fileStates[_fileKey(id, task.filename)] = state;
      if (task.filename == 'book.pdf') _states[id] = state;
    }
    notifyListeners();
  }

  // Serialize start/cancel/remove per book, while allowing different books together.
  Future<void> _exclusive(String id, Future<void> Function() action) {
    final previous = _operations[id] ?? Future<void>.value();
    late Future<void> operation;
    operation = previous
        .catchError((Object _) {})
        .then((_) => action())
        .whenComplete(() {
      if (identical(_operations[id], operation)) {
        _operations.remove(id);
        _refresh(id);
      }
    });
    _operations[id] = operation;
    return operation;
  }

  Future<void> ensureState(Book book) async {
    try {
      await initialize();
      await _exclusive(book.id, () async {
        final directory = await _bookDirectory(book.id);
        final pdf = File('${directory.path}/book.pdf');
        if (await pdf.exists() && await pdf.length() > 0) {
          _states[book.id] =
              const BookDownloadState(status: BookDownloadStatus.downloaded);
        }
        for (var i = 0; i < book.audio.length; i++) {
          final path = await localAudioPath(book, i);
          if (path != null) {
            _fileStates[_fileKey(book.id, _audioFilename(book, i))] =
                const BookDownloadState(status: BookDownloadStatus.downloaded);
          }
        }
        for (final task in _plans[book.id] ?? <DownloadTask>[]) {
          final file = await _fileForTask(task);
          if (await file.exists() && await file.length() > 0) {
            _records[task.taskId] =
                TaskRecord(task, TaskStatus.complete, 1, await file.length());
          }
        }
        notifyListeners();
      });
    } catch (_) {
      _setState(
          book.id, const BookDownloadState(status: BookDownloadStatus.failed));
    }
  }

  Future<String?> localAudioPath(Book book, int index) async {
    final directory = await _bookDirectory(book.id);
    final file = File('${directory.path}/audio/${_audioFilename(book, index)}');
    return await file.exists() && await file.length() > 0 ? file.path : null;
  }

  /// Missing audio remains streamable; only the PDF is required for reading.
  Future<Book?> localBook(Book book) async {
    final directory = await _bookDirectory(book.id);
    final pdf = File('${directory.path}/book.pdf');
    if (!await pdf.exists() || await pdf.length() == 0) return null;
    return _withAvailableAudio(book, pdf.path);
  }

  Future<Book> playableBook(Book book) =>
      _withAvailableAudio(book, book.pdfAsset);

  Future<Book> _withAvailableAudio(Book book, String pdfPath) async =>
      book.copyWithLocalMedia(pdfPath: pdfPath, audioPaths: [
        for (var i = 0; i < book.audio.length; i++)
          await localAudioPath(book, i) ?? book.audio[i].downloadSource,
      ]);

  /// The library's download action downloads the PDF only.
  Future<void> download(Book book) => _downloadFile(book);
  Future<void> downloadChapter(Book book, int index) =>
      _downloadFile(book, index: index);

  Future<void> _downloadFile(Book book, {int? index}) =>
      _exclusive(book.id, () async {
        await initialize();
        final filename =
            index == null ? 'book.pdf' : _audioFilename(book, index);
        final url =
            index == null ? book.pdfAsset : book.audio[index].downloadSource;
        final tasks = _plans.putIfAbsent(book.id, () => []);
        final previous = tasks.where((t) => t.filename == filename).firstOrNull;
        final previousRecord =
            previous == null ? null : _records[previous.taskId];
        if (previousRecord != null &&
            !previousRecord.status.isFinalState &&
            previousRecord.status != TaskStatus.paused) {
          return;
        }
        final directory =
            'book_downloads/${_safeId(book.id)}${index == null ? '' : '/audio'}';
        final task = previous != null &&
                previous.url == url &&
                previousRecord?.status == TaskStatus.paused
            ? previous
            : DownloadTask(
                url: url,
                filename: filename,
                directory: directory,
                baseDirectory: BaseDirectory.applicationSupport,
                group: _group,
                metaData: book.id,
                updates: Updates.statusAndProgress,
                retries: 5,
                allowPause: true);
        tasks.removeWhere((t) => t.filename == filename);
        tasks.add(task);
        try {
          await _savePlan(book.id);
          final file = await _fileForTask(task);
          if (await file.exists() && await file.length() > 0) {
            _records[task.taskId] =
                TaskRecord(task, TaskStatus.complete, 1, await file.length());
            return;
          }
          final size =
              index == null ? book.pdfFileSize : book.audio[index].fileSize;
          _records[task.taskId] =
              TaskRecord(task, TaskStatus.enqueued, 0, size);
          _fileStates[_fileKey(book.id, filename)] = BookDownloadState(
              status: BookDownloadStatus.downloading, totalBytes: size);
          if (index == null) {
            _states[book.id] = _fileStates[_fileKey(book.id, filename)]!;
          }
          notifyListeners();
          var accepted = false;
          if (identical(task, previous) &&
              previousRecord?.status == TaskStatus.paused) {
            accepted = await _downloader.resume(task);
          }
          if (!accepted) accepted = await _downloader.enqueue(task);
          if (!accepted) throw StateError('Download was not accepted');
        } catch (_) {
          _records[task.taskId] = TaskRecord(task, TaskStatus.failed, 0, -1);
        }
      });

  // Cancelling the PDF must not cancel individually requested audio files.
  Future<void> cancel(String id) =>
      _exclusive(id, () => _cancel(id, filename: 'book.pdf'));
  Future<void> cancelChapter(Book book, int index) => _exclusive(
      book.id, () => _cancel(book.id, filename: _audioFilename(book, index)));

  Future<void> _cancel(String id, {String? filename}) async {
    await initialize();
    final tasks = (_plans[id] ?? <DownloadTask>[])
        .where((t) => filename == null || t.filename == filename)
        .toList();
    await _downloader.cancelTasksWithIds([
      for (final t in tasks)
        if (_records[t.taskId]?.status != TaskStatus.complete) t.taskId
    ]);
    for (final t in tasks) {
      if (_records[t.taskId]?.status != TaskStatus.complete) {
        _records[t.taskId] = TaskRecord(t, TaskStatus.canceled, 0, -1);
      }
    }
  }

  Future<void> removeChapter(Book book, int index) =>
      _exclusive(book.id, () async {
        final filename = _audioFilename(book, index);
        await _cancel(book.id, filename: filename);
        _plans[book.id]?.removeWhere((t) => t.filename == filename);
        if (_plans.containsKey(book.id)) await _savePlan(book.id);
        final path = await localAudioPath(book, index);
        if (path != null) await File(path).delete();
        _fileStates.remove(_fileKey(book.id, filename));
        notifyListeners();
      });

  Future<void> remove(Book book) async {
    await _exclusive(book.id, () async {
      await _cancel(book.id);
      _plans.remove(book.id);
      _fileStates.removeWhere((key, _) => key.startsWith('${book.id}::'));
      final manifest = await _manifest(book.id);
      if (await manifest.exists()) await manifest.delete();
      final target = await _bookDirectory(book.id);
      if (await target.exists()) await target.delete(recursive: true);
      final legacyPartial = Directory('${target.path}.partial');
      if (await legacyPartial.exists()) {
        await legacyPartial.delete(recursive: true);
      }
      _setState(book.id, const BookDownloadState());
    });
  }

  Future<void> _savePlan(String id) async {
    final file = await _manifest(id);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
        jsonEncode({
          'bookId': id,
          'tasks': _plans[id]!.map((t) => t.toJson()).toList()
        }),
        flush: true);
    await temp.rename(file.path);
  }

  String _safeId(String id) =>
      base64Url.encode(utf8.encode(id)).replaceAll('=', '');
  Future<Directory> _root() async {
    if (_rootOverride != null) return _rootOverride;
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/book_downloads')
      ..createSync(recursive: true);
  }

  Future<File> _fileForTask(DownloadTask task) async => File(
      '${(await _root()).path}/${task.directory.substring('book_downloads/'.length)}/${task.filename}');
  Future<File> _manifest(String id) async =>
      File('${(await _root()).path}/${_safeId(id)}.json');
  Future<Directory> _bookDirectory(String id) async =>
      Directory('${(await _root()).path}/${_safeId(id)}');
  String _extension(String source) {
    final name = Uri.tryParse(source)?.pathSegments.lastOrNull ?? '';
    final dot = name.lastIndexOf('.');
    return dot < 0 || name.length - dot > 6
        ? '.mp3'
        : name.substring(dot).toLowerCase();
  }

  void _setState(String id, BookDownloadState state) {
    _states[id] = state;
    notifyListeners();
  }
}
