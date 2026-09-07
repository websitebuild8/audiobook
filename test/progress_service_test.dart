import 'package:flutter_test/flutter_test.dart';
import 'package:maktaba_athariyya/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
