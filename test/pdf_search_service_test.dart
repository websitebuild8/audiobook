import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:maktaba_athariyya/services/pdf_search_service.dart';

PdfPageText page(int number, String text) => PdfPageText(
    pageNumber: number,
    fullText: text,
    charRects: const [],
    fragments: const []);
void main() {
  test('image-only pages never enable search; a text page after a cover does',
      () async {
    final empty = PdfSearchService();
    await empty.index(3, (n) async => page(n, ' \n'));
    expect(empty.hasText, false);
    expect(empty.indexing, false);
    empty.dispose();
    final mixed = PdfSearchService();
    await mixed.index(3, (n) async => page(n, n == 3 ? 'ފޮތް ފޮތް' : ''));
    expect(mixed.hasText, true);
    mixed.search('ފޮތް');
    expect(mixed.matches.length, 2);
    expect(mixed.matches.map((m) => m.pageNumber), [3, 3]);
    mixed.dispose();
  });
  test('literal punctuation, mixed case, phrases across lines, and clearing',
      () async {
    final service = PdfSearchService();
    await service.index(
        2, (n) async => page(n, 'Book book [a+b] hello\nworld'));
    service.search('BOOK');
    expect(service.matches.length, 4);
    service.search('[a+b]');
    expect(service.matches.length, 2);
    service.search('hello world');
    expect(service.matches.length, 2);
    service.search('missing');
    expect(service.matches, isEmpty);
    service.search(' ');
    expect(service.matches, isEmpty);
    service.dispose();
  });
  test('bad pages do not prevent later text and errors are marked partial',
      () async {
    final service = PdfSearchService();
    await service.index(2, (n) async {
      if (n == 1) throw StateError('bad page');
      return page(n, 'text');
    });
    expect(service.incomplete, true);
    expect(service.hasText, true);
    service.dispose();
  });
  test(
      'closing while extraction is pending stops further work and notifications',
      () async {
    final service = PdfSearchService();
    final pending = Completer<PdfPageText>();
    var loads = 0;
    final indexing = service.index(3, (_) {
      loads++;
      return pending.future;
    });
    service.dispose();
    pending.complete(page(1, 'text'));
    await indexing;
    expect(loads, 1);
  });
}
