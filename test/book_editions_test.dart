import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktaba_athariyya/services/catalog_service.dart';

void main() {
  test('both editions share PDF while reading-only downloads exclude audio',
      () async {
    SharedPreferences.setMockInitialValues({
      'remote_catalog_updated_at_v1': DateTime.now().millisecondsSinceEpoch,
      'remote_catalog_v1': jsonEncode([
        {
          'id': 12,
          'sourceId': 'existing-id',
          'title': 'Book',
          'publishReadingOnlyEdition': true,
          'showReaderNotice': true,
          'pdf': {'url': 'https://example.com/book.pdf', 'filesize': 100},
          'audioChapters': [
            {
              'title': 'Chapter',
              'order': 1,
              'audio': {'url': 'https://example.com/audio.mp3', 'filesize': 500}
            }
          ],
        }
      ]),
    });
    final books = await CatalogService.load();
    expect(books, hasLength(2));
    expect(books.first.id, 'existing-id');
    expect(books.last.id, 'reading::existing-id');
    expect(books.first.totalDownloadSize, 600);
    expect(books.last.totalDownloadSize, 100);
    expect(books.last.audio, isEmpty);
    expect(books.last.pdfAsset, books.first.pdfAsset);
    expect(books.last.showReaderNotice, isTrue);
    expect(books.where((book) => book.hasAudio), hasLength(1));
  });
  test('old records and records without audio remain single editions',
      () async {
    SharedPreferences.setMockInitialValues({
      'remote_catalog_updated_at_v1': DateTime.now().millisecondsSinceEpoch,
      'remote_catalog_v1': jsonEncode([
        {
          'id': 1,
          'pdf': {'url': 'https://example.com/one.pdf'},
          'publishReadingOnlyEdition': true
        },
        {
          'id': 2,
          'pdf': {'url': 'https://example.com/two.pdf'},
          'audioChapters': [
            {
              'audio': {'url': 'https://example.com/audio.mp3'}
            }
          ]
        },
      ]),
    });
    expect(await CatalogService.load(), hasLength(2));
  });
}
