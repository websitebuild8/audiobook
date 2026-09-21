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
  test('queues every chapter and prevents simultaneous duplicate starts',
      () async {
    await Future.wait([service.download(book), service.download(book)]);
    expect(native.tasks, hasLength(3));
    await service.ensureState(book); // A rebuilt tab must not clear progress.
    expect(service.stateFor(book.id).status, BookDownloadStatus.downloading);
    expect(await service.localBook(book), isNull);
  });
  test('retry and a new app session keep completed chapters', () async {
    await service.download(book);
    final pdf = native.tasks.first;
    final completed = File(
        '${directory.path}/${pdf.directory.substring('book_downloads/'.length)}/${pdf.filename}');
    await completed.parent.create(recursive: true);
    await completed.writeAsString('completed PDF');
    native.status!(TaskStatusUpdate(pdf, TaskStatus.complete));
    await service.cancel(book.id);
    final nextNative = FakeDownloader();
    final restored = DownloadService.forTesting(nextNative, directory);
    await restored.initialize();
    await restored.download(book);
    expect(nextNative.tasks, hasLength(2));
    expect(nextNative.tasks.every((t) => t.filename.endsWith('.mp3')), isTrue);
    expect(await completed.readAsString(), 'completed PDF');
    restored.dispose();
  });
  test('failure of a chapter never marks the whole audiobook downloaded',
      () async {
    await service.download(book);
    native.status!(TaskStatusUpdate(native.tasks[0], TaskStatus.complete));
    native.status!(TaskStatusUpdate(native.tasks[1], TaskStatus.complete));
    native.status!(TaskStatusUpdate(native.tasks[2], TaskStatus.failed));
    expect(service.stateFor(book.id).status, BookDownloadStatus.failed);
  });
  test('remove cancels tasks and removes only that book', () async {
    await service.download(book);
    await service.remove(book);
    expect(service.stateFor(book.id).status, BookDownloadStatus.notDownloaded);
    expect(await directory.list().toList(), isEmpty);
  });
  test('native enqueue errors leave a retryable state', () async {
    native.reject = true;
    await service.download(book);
    expect(service.stateFor(book.id).status, BookDownloadStatus.failed);
    native.reject = false;
    await service.download(book);
    expect(native.tasks, hasLength(3));
    expect(service.stateFor(book.id).status, BookDownloadStatus.downloading);
  });
  test('two books queue independently and cancel does not cross books',
      () async {
    const other = Book(
        id: 'two',
        title: 'Other',
        category: 'test',
        pdfAsset: 'https://example.com/other.pdf');
    await Future.wait([service.download(book), service.download(other)]);
    expect(native.tasks, hasLength(4));
    await service.cancel(book.id);
    expect(service.stateFor(other.id).status, BookDownloadStatus.downloading);
    expect(service.stateFor(book.id).status, BookDownloadStatus.failed);
  });
}
