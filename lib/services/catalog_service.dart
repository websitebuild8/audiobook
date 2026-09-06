import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/book.dart';

abstract final class CatalogService {
  static Future<List<Book>> load() async {
    final catalogJson = jsonDecode(
      await rootBundle.loadString('assets/catalog.json'),
    ) as Map<String, dynamic>;
    final entries = catalogJson['books'] as List<dynamic>;

    return entries.map((value) {
      final entry = value as Map<String, dynamic>;
      final id = entry['id'] as String;
      final title = entry['title'] as String;
      final audioAssets = List<String>.from(
        entry['audioAssets'] as List<dynamic>? ?? const [],
      )..sort(_naturalAudioSort);
      return Book(
        id: id,
        title: title,
        category: entry['category'] as String,
        pdfAsset: entry['pdfAsset'] as String,
        coverAsset: entry['coverAsset'] as String?,
        audio: audioAssets
            .map(
              (asset) => AudioChapter(
                title: _audioTitle(asset),
                assetPath: asset,
              ),
            )
            .toList(),
      );
    }).toList();
  }

  static String _audioTitle(String path) {
    final name = path
        .split('/')
        .last
        .replaceFirst(RegExp(r'\.mp3$', caseSensitive: false), '');
    final shortName = name.split(' - ').first;
    return shortName.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
  }

  static int _naturalAudioSort(String a, String b) {
    final aNumber = int.tryParse(a.split('/').last.split('.').first) ?? 0;
    final bNumber = int.tryParse(b.split('/').last.split('.').first) ?? 0;
    return aNumber.compareTo(bNumber);
  }
}
