import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';

abstract final class CatalogService {
  static const apiBaseUrl = 'https://www.athariyya.online/api';
  static const _cacheKey = 'remote_catalog_v1';
  static const _cacheTimeKey = 'remote_catalog_updated_at_v1';
  static const _cacheLifetime = Duration(minutes: 5);

  @visibleForTesting
  static List<Book>? testBooks;

  static Future<List<Book>> load({bool refresh = false}) async {
    if (testBooks case final List<Book> books) return books;
    final prefs = await SharedPreferences.getInstance();
    if (!refresh) {
      final cached = _freshCachedCatalog(prefs);
      if (cached != null) return cached;
    }

    try {
      final documents = await _fetchAllBooks();
      await prefs.setString(_cacheKey, jsonEncode(documents));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      return _booksFromRemoteDocuments(documents);
    } catch (_) {
      final cached = _cachedCatalog(prefs);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static List<Book>? _freshCachedCatalog(SharedPreferences prefs) {
    final updatedAt = prefs.getInt(_cacheTimeKey);
    if (updatedAt == null) return null;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
    return age < _cacheLifetime ? _cachedCatalog(prefs) : null;
  }

  static List<Book>? _cachedCatalog(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return _booksFromRemoteDocuments(
        (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAllBooks() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final documents = <Map<String, dynamic>>[];
    var page = 1;
    try {
      while (true) {
        final uri = Uri.parse('$apiBaseUrl/books').replace(
          queryParameters: {
            'depth': '2',
            'limit': '100',
            'page': '$page',
            'sort': 'order',
          },
        );
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(
              const Duration(seconds: 15),
            );
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw HttpException(
            'Catalogue request failed (${response.statusCode})',
            uri: uri,
          );
        }
        final body = await utf8.decoder.bind(response).join();
        final payload = jsonDecode(body) as Map<String, dynamic>;
        documents.addAll(
          (payload['docs'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>(),
        );
        if (payload['hasNextPage'] != true) break;
        page = (payload['nextPage'] as num?)?.toInt() ?? page + 1;
      }
      return documents;
    } finally {
      client.close(force: true);
    }
  }

  static List<Book> _booksFromRemoteDocuments(
    List<Map<String, dynamic>> documents,
  ) {
    return documents
        .expand((entry) {
          final category = entry['category'];
          final categoryName = category is Map<String, dynamic>
              ? category['name'] as String? ?? ''
              : '';
          final chapters = (entry['audioChapters'] as List<dynamic>? ??
                  const [])
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort(
              (a, b) => ((a['order'] as num?)?.toInt() ?? 0).compareTo(
                (b['order'] as num?)?.toInt() ?? 0,
              ),
            );
          final id = entry['sourceId'] as String? ?? 'payload::${entry['id']}';
          final book = Book(
            id: id,
            title: entry['title'] as String? ?? '',
            category: categoryName,
            pdfAsset: _mediaUrl(entry['pdf']) ?? '',
            pdfFileSize: _mediaSize(entry['pdf']),
            showReaderNotice: entry['showReaderNotice'] == true,
            coverAsset: _mediaUrl(entry['cover'], cacheBust: true),
            audio: [
              for (final chapter in chapters)
                if (_mediaUrl(chapter['audio']) case final String audioUrl)
                  AudioChapter(
                    title: chapter['title'] as String? ?? '',
                    assetPath: audioUrl,
                    fileSize: _mediaSize(chapter['audio']),
                  ),
            ],
          );
          return [
            book,
            if (entry['publishReadingOnlyEdition'] == true && book.hasAudio)
              Book(
                id: 'reading::${book.id}',
                title: '${book.title} (PDF)',
                category: book.category,
                pdfAsset: book.pdfAsset,
                pdfFileSize: book.pdfFileSize,
                coverAsset: book.coverAsset,
                showReaderNotice: book.showReaderNotice,
              ),
          ];
        })
        .where((book) => book.pdfAsset.isNotEmpty)
        .toList(growable: false);
  }

  static String? _mediaUrl(dynamic media, {bool cacheBust = false}) {
    if (media is! Map<String, dynamic>) return null;
    final url = media['url'];
    if (url is! String || url.isEmpty) return null;
    final updatedAt = media['updatedAt'];
    if (!cacheBust || updatedAt is! String || updatedAt.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri.replace(
        queryParameters: {...uri.queryParameters, 'v': updatedAt}).toString();
  }

  static int _mediaSize(dynamic media) {
    if (media is! Map<String, dynamic>) return 0;
    return (media['filesize'] as num?)?.toInt() ?? 0;
  }
}
