import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('summary counts only current catalogue books once and follows undo',
      () async {
    await ProgressService.setRead('a', true);
    await ProgressService.setRead('removed', true);
    expect(await ProgressService.readingSummary(['a', 'b', 'a']),
        (completed: 1, total: 2));
    await ProgressService.setRead('a', false);
    expect(await ProgressService.readingSummary(['a', 'b']),
        (completed: 0, total: 2));
    expect(await ProgressService.readingSummary([]), (completed: 0, total: 0));
  });

  test('completion is explicit, persists independently and can be undone',
      () async {
    expect(await ProgressService.isRead('a'), isFalse);
    await ProgressService.savePage('a', 100);
    expect(await ProgressService.isRead('a'), isFalse);
    await ProgressService.setRead('a', true);
    expect(await ProgressService.isRead('a'), isTrue);
    expect(await ProgressService.isRead('b'), isFalse);
    await ProgressService.setRead('a', false);
    expect(await ProgressService.isRead('a'), isFalse);
    expect(await ProgressService.pageFor('a'), 100);
  });

  test('recent reads keeps three distinct books in most-recent order',
      () async {
    await ProgressService.recordBookOpened('book-a', 2);
    await ProgressService.recordBookOpened('book-b', 4);
    await ProgressService.recordBookOpened('book-c', 6);
    await ProgressService.recordBookOpened('book-a', 9);
    await ProgressService.recordBookOpened('book-d', 3);

    final recent = await ProgressService.recentReads();

    expect(recent.map((item) => item.bookId), ['book-d', 'book-a', 'book-c']);
    expect(recent[1].page, 9);
  });

  test('saved page updates the resume point without changing recent order',
      () async {
    await ProgressService.recordBookOpened('book-a', 1);
    await ProgressService.recordBookOpened('book-b', 2);

    await ProgressService.savePage('book-a', 14);
    final recent = await ProgressService.recentReads();

    expect(recent.map((item) => item.bookId), ['book-b', 'book-a']);
    expect(recent[1].page, 14);
  });
}
