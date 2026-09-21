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

/// Aggregates a whole book: a finished PDF alone is not a finished audiobook.
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
    totalBytes: total,
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

  void _refresh(String id) {
    final tasks = _plans[id];
    if (tasks == null || _operations.containsKey(id)) return;
    _setState(
        id,
        aggregateDownloadState([
          for (final t in tasks)
            if (_records[t.taskId] case final r?) r
        ], tasks.length));
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
      if (_operations.containsKey(book.id)) return;
      if (_plans.containsKey(book.id)) {
        _refresh(book.id);
        return;
      }
      final before = _states[book.id];
      final local = await localBook(book);
      // A download may have started while the filesystem check was in flight.
      if (_operations.containsKey(book.id) ||
          _plans.containsKey(book.id) ||
          !identical(before, _states[book.id])) {
        return;
      }
      _setState(
          book.id,
          BookDownloadState(
              status: local == null
                  ? BookDownloadStatus.notDownloaded
                  : BookDownloadStatus.downloaded));
    } catch (_) {
      if (!_operations.containsKey(book.id)) {
        _setState(book.id,
            const BookDownloadState(status: BookDownloadStatus.failed));
      }
    }
  }

  Future<Book?> localBook(Book book) async {
    final directory = await _bookDirectory(book.id);
    final pdf = File('${directory.path}/book.pdf');
    if (!await pdf.exists() || await pdf.length() == 0) return null;
    final audioPaths = <String>[];
    for (var index = 0; index < book.audio.length; index++) {
      final file = File(
          '${directory.path}/audio/${index.toString().padLeft(3, '0')}${_extension(book.audio[index].assetPath)}');
      if (!await file.exists() || await file.length() == 0) return null;
      audioPaths.add(file.path);
    }
    return book.copyWithLocalMedia(pdfPath: pdf.path, audioPaths: audioPaths);
  }

  Future<void> download(Book book) => _exclusive(book.id, () async {
        try {
          await initialize();
          final oldTasks = _plans[book.id] ?? [];
          if (oldTasks.any((t) {
            final s = _records[t.taskId]?.status;
            return s != null && !s.isFinalState && s != TaskStatus.paused;
          })) {
            return;
          }
          _setState(book.id,
              const BookDownloadState(status: BookDownloadStatus.downloading));
          final directory = 'book_downloads/${_safeId(book.id)}';
          final tasks = <DownloadTask>[
            DownloadTask(
                url: book.pdfAsset,
                filename: 'book.pdf',
                directory: directory,
                baseDirectory: BaseDirectory.applicationSupport,
                group: _group,
                metaData: book.id,
                updates: Updates.statusAndProgress,
                retries: 5,
                allowPause: true),
            for (var i = 0; i < book.audio.length; i++)
              DownloadTask(
                  url: book.audio[i].assetPath,
                  filename:
                      '${i.toString().padLeft(3, '0')}${_extension(book.audio[i].assetPath)}',
                  directory: '$directory/audio',
                  baseDirectory: BaseDirectory.applicationSupport,
                  group: _group,
                  metaData: book.id,
                  updates: Updates.statusAndProgress,
                  retries: 5,
                  allowPause: true),
          ];
          // Retain native pause data and completed chapters when retrying.
          for (var i = 0; i < tasks.length; i++) {
            final matching = oldTasks.where((t) =>
                t.url == tasks[i].url && t.filename == tasks[i].filename);
            if (matching.isNotEmpty &&
                _records[matching.first.taskId]?.status == TaskStatus.paused) {
              tasks[i] = matching.first;
            }
          }
          _plans[book.id] = tasks;
          await _savePlan(book.id);
          // Enqueue every file now. Native execution must not depend on Dart
          // waking up to enqueue the next audiobook chapter.
          for (final task in tasks) {
            final file = await _fileForTask(task);
            if (await file.exists() && await file.length() > 0) {
              _records[task.taskId] =
                  TaskRecord(task, TaskStatus.complete, 1, await file.length());
              continue;
            }
            final wasPaused =
                _records[task.taskId]?.status == TaskStatus.paused;
            _records[task.taskId] =
                TaskRecord(task, TaskStatus.enqueued, 0, -1);
            var accepted = false;
            try {
              if (wasPaused) accepted = await _downloader.resume(task);
              if (!accepted) accepted = await _downloader.enqueue(task);
            } catch (_) {
              accepted = false;
            }
            if (!accepted) {
              _records[task.taskId] =
                  TaskRecord(task, TaskStatus.failed, 0, -1);
            }
          }
        } catch (_) {
          for (final t in _plans[book.id] ?? <DownloadTask>[]) {
            _records.putIfAbsent(
                t.taskId, () => TaskRecord(t, TaskStatus.failed, 0, -1));
          }
          _setState(book.id,
              const BookDownloadState(status: BookDownloadStatus.failed));
        }
      });

  Future<void> cancel(String id) => _exclusive(id, () => _cancel(id));

  Future<void> _cancel(String id) async {
    await initialize();
    await _downloader.cancelTasksWithIds(
        [for (final t in _plans[id] ?? <DownloadTask>[]) t.taskId]);
    for (final t in _plans[id] ?? <DownloadTask>[]) {
      final r = _records[t.taskId];
      if (r?.status != TaskStatus.complete) {
        _records[t.taskId] = TaskRecord(t, TaskStatus.canceled, 0, -1);
      }
    }
  }

  Future<void> remove(Book book) async {
    await _exclusive(book.id, () async {
      await _cancel(book.id);
      _plans.remove(book.id);
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
