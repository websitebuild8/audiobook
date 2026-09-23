import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/models/book.dart';
import 'package:maktaba_athariyya/services/download_service.dart';

class FakeDatabase implements Database {
  @override
  Future<List<TaskRecord>> allRecords({String? group}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDownloader implements FileDownloader {
  final tasks = <Task>[];
  bool reject = false;
  TaskStatusCallback? status;
  @override
  Database get database => FakeDatabase();
  @override
  FileDownloader registerCallbacks(
      {String group = 'default',
      TaskStatusCallback? taskStatusCallback,
      TaskProgressCallback? taskProgressCallback,
      TaskNotificationTapCallback? taskNotificationTapCallback}) {
    status = taskStatusCallback;
    return this;
  }

  @override
  Future<void> start(
      {bool doTrackTasks = true,
      bool markDownloadedComplete = true,
      bool doRescheduleKilledTasks = true,
      bool autoCleanDatabase = false}) async {}
  @override
  Future<(List<Task>, List<Task>)> rescheduleKilledTasks() async =>
      (<Task>[], <Task>[]);
  @override
  Future<bool> enqueue(Task task) async {
    if (reject) throw StateError('enqueue unavailable');
    tasks.add(task);
    return true;
  }

  @override
  Future<bool> cancelTasksWithIds(Iterable<String> ids) async {
    for (final task in tasks.where((t) => ids.contains(t.taskId))) {
      status!(TaskStatusUpdate(task, TaskStatus.canceled));
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const book = Book(
    id: 'one',
    title: 'Book',
    category: 'test',
    pdfAsset: 'https://example.com/book.pdf',
    audio: [
      AudioChapter(title: 'One', assetPath: 'https://example.com/one.mp3'),
      AudioChapter(title: 'Two', assetPath: 'https://example.com/two.mp3')
    ]);
void main() {
  late Directory directory;
  late FakeDownloader native;
  late DownloadService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('book-download-test');
    native = FakeDownloader();
    service = DownloadService.forTesting(native, directory);
  });
  tearDown(() async {
    service.dispose();
    await directory.delete(recursive: true);
  });

  Future<File> complete(Task task) async {
    final file = File(
        '${directory.path}/${task.directory.substring('book_downloads/'.length)}/${task.filename}');
    await file.parent.create(recursive: true);
    await file.writeAsString('downloaded content');
    native.status!(TaskStatusUpdate(task, TaskStatus.complete));
    return file;
  }

  test(
      'PDF download queues only the PDF and duplicate taps do not duplicate tasks',
      () async {
    await Future.wait([service.download(book), service.download(book)]);
    expect(native.tasks, hasLength(1));
    expect(native.tasks.single.filename, 'book.pdf');
    await service.ensureState(book);
    expect(service.stateFor(book.id).status, BookDownloadStatus.downloading);
    await complete(native.tasks.single);
    final local = await service.localBook(book);
    expect(local, isNotNull);
    expect(local!.audio.first.assetPath, book.audio.first.assetPath);
    expect(service.stateFor(book.id).status, BookDownloadStatus.downloaded);
  });

  test('chapter downloads are independent of PDF and sibling chapters',
      () async {
    await Future.wait(
        [service.downloadChapter(book, 1), service.downloadChapter(book, 1)]);
    expect(native.tasks, hasLength(1));
    expect(native.tasks.single.url, book.audio[1].assetPath);
    expect(service.stateFor(book.id).status, BookDownloadStatus.notDownloaded);
    expect(service.chapterStateFor(book, 0).status,
        BookDownloadStatus.notDownloaded);
    final file = await complete(native.tasks.single);
    final playable = await service.playableBook(book);
    expect(playable.audio[1].assetPath, file.path);
    expect(playable.audio[1].downloadSource, book.audio[1].assetPath);
    expect(await service.localBook(book), isNull);
  });

  test('cancelling one file leaves the PDF and other chapter downloading',
      () async {
    await service.download(book);
    await service.downloadChapter(book, 0);
    await service.downloadChapter(book, 1);
    await service.cancelChapter(book, 0);
    expect(service.chapterStateFor(book, 0).status, BookDownloadStatus.failed);
    expect(service.chapterStateFor(book, 1).status,
        BookDownloadStatus.downloading);
    expect(service.stateFor(book.id).status, BookDownloadStatus.downloading);
    await service.cancel(book.id);
    expect(service.chapterStateFor(book, 1).status,
        BookDownloadStatus.downloading);
  });

  test(
      'completed chapters survive restart and only a failed chapter is retried',
      () async {
    await service.downloadChapter(book, 0);
    final saved = await complete(native.tasks.single);
    await service.downloadChapter(book, 1);
    native.status!(TaskStatusUpdate(native.tasks.last, TaskStatus.failed));
    final nextNative = FakeDownloader();
    final restored = DownloadService.forTesting(nextNative, directory);
    await restored.initialize();
    await restored.downloadChapter(book, 1);
    expect(nextNative.tasks, hasLength(1));
    expect(nextNative.tasks.single.url, book.audio[1].assetPath);
    expect(restored.chapterStateFor(book, 0).status,
        BookDownloadStatus.downloaded);
    expect(await saved.readAsString(), 'downloaded content');
    restored.dispose();
  });

  test(
      'removing a chapter retains the PDF and sibling audio, with the original URL available',
      () async {
    await service.download(book);
    await complete(native.tasks.last);
    await service.downloadChapter(book, 0);
    await complete(native.tasks.last);
    await service.downloadChapter(book, 1);
    await complete(native.tasks.last);
    final local = (await service.localBook(book))!;
    await service.removeChapter(local, 0);
    expect(await service.localAudioPath(book, 0), isNull);
    expect(await service.localAudioPath(book, 1), isNotNull);
    expect(await service.localBook(book), isNotNull);
    expect(service.chapterStateFor(book, 0).status,
        BookDownloadStatus.notDownloaded);
    await service.downloadChapter(local, 0);
    expect(native.tasks.last.url, book.audio[0].assetPath);
  });

  test('legacy downloaded files are recognized without downloading again',
      () async {
    // Existing releases store files in these same book directories.
    await service.download(book);
    final pdf = native.tasks.single;
    await complete(pdf);
    final legacyAudio = File(
        '${directory.path}/${pdf.directory.substring('book_downloads/'.length)}/audio/000.mp3');
    await legacyAudio.parent.create(recursive: true);
    await legacyAudio.writeAsString('legacy audio');
    await service.ensureState(book);
    expect(
        service.chapterStateFor(book, 0).status, BookDownloadStatus.downloaded);
    expect(
        (await service.localBook(book))!.audio[0].assetPath, legacyAudio.path);
    await service.downloadChapter(book, 0);
    expect(native.tasks, hasLength(1));
  });

  test('native enqueue errors leave a retryable individual file', () async {
    native.reject = true;
    await service.downloadChapter(book, 1);
    expect(service.chapterStateFor(book, 1).status, BookDownloadStatus.failed);
    native.reject = false;
    await service.downloadChapter(book, 1);
    expect(native.tasks, hasLength(1));
    expect(service.chapterStateFor(book, 1).status,
        BookDownloadStatus.downloading);
  });

  test(
      'remove book cancels every associated file but leaves another book alone',
      () async {
    const other = Book(
        id: 'two',
        title: 'Other',
        category: 'test',
        pdfAsset: 'https://example.com/other.pdf');
    await service.download(book);
    await service.downloadChapter(book, 1);
    await service.download(other);
    await service.remove(book);
    expect(service.stateFor(book.id).status, BookDownloadStatus.notDownloaded);
    expect(service.chapterStateFor(book, 1).status,
        BookDownloadStatus.notDownloaded);
    expect(service.stateFor(other.id).status, BookDownloadStatus.downloading);
  });
}
