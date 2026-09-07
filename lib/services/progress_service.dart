import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentRead {
  const RecentRead({
    required this.bookId,
    required this.page,
    required this.openedAt,
  });

  final String bookId;
  final int page;
  final DateTime openedAt;
}

abstract final class ProgressService {
  static const _recentReadsKey = 'recent_reads_v1';
  static const _recentReadsLimit = 3;
  static String _pageKey(String bookId) => 'page::$bookId';
  static String _bookmarkKey(String bookId, int page) =>
      'bookmark::$bookId::$page';
  static String _audioChapterKey(String bookId) => 'audio_chapter::$bookId';
  static String _audioPositionKey(String bookId) => 'audio_position::$bookId';

  static Future<int> pageFor(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pageKey(bookId)) ?? 1;
  }

  static Future<void> savePage(String bookId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pageKey(bookId), page);
    final recent = _readRecent(prefs);
    final index = recent.indexWhere((item) => item.bookId == bookId);
    if (index < 0) return;
    final current = recent[index];
    recent[index] = RecentRead(
      bookId: bookId,
      page: page,
      openedAt: current.openedAt,
    );
    await _writeRecent(prefs, recent);
  }

  static Future<void> recordBookOpened(String bookId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = _readRecent(prefs)
      ..removeWhere((item) => item.bookId == bookId)
      ..insert(
        0,
        RecentRead(
          bookId: bookId,
          page: page < 1 ? 1 : page,
          openedAt: DateTime.now(),
        ),
      );
    await _writeRecent(prefs, recent.take(_recentReadsLimit).toList());
  }

  static Future<List<RecentRead>> recentReads() async {
    final prefs = await SharedPreferences.getInstance();
    return _readRecent(prefs).take(_recentReadsLimit).toList(growable: false);
  }

  static List<RecentRead> _readRecent(SharedPreferences prefs) {
    final raw = prefs.getString(_recentReadsKey);
    if (raw == null || raw.isEmpty) return <RecentRead>[];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map((value) {
            final bookId = value['bookId'];
            final page = value['page'];
            final openedAt = value['openedAt'];
            if (bookId is! String || page is! int || openedAt is! int) {
              return null;
            }
            return RecentRead(
              bookId: bookId,
              page: page < 1 ? 1 : page,
              openedAt: DateTime.fromMillisecondsSinceEpoch(openedAt),
            );
          })
          .whereType<RecentRead>()
          .toList();
    } on FormatException {
      return <RecentRead>[];
    } on TypeError {
      return <RecentRead>[];
    }
  }

  static Future<void> _writeRecent(
    SharedPreferences prefs,
    List<RecentRead> recent,
  ) async {
    await prefs.setString(
      _recentReadsKey,
      jsonEncode([
        for (final item in recent)
          {
            'bookId': item.bookId,
            'page': item.page,
            'openedAt': item.openedAt.millisecondsSinceEpoch,
          },
      ]),
    );
  }

  static Future<bool> isBookmarked(String bookId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bookmarkKey(bookId, page)) ?? false;
  }

  static Future<bool> toggleBookmark(String bookId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _bookmarkKey(bookId, page);
    final next = !(prefs.getBool(key) ?? false);
    await prefs.setBool(key, next);
    return next;
  }

  static Future<void> removeBookmark(String bookId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookmarkKey(bookId, page));
  }

  static Future<void> addBookmark(String bookId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bookmarkKey(bookId, page), true);
  }

  static Future<Map<String, List<int>>> bookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, List<int>>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('bookmark::') || prefs.getBool(key) != true) {
        continue;
      }
      final value = key.substring('bookmark::'.length);
      final separator = value.lastIndexOf('::');
      if (separator < 1) continue;
      final bookId = value.substring(0, separator);
      final page = int.tryParse(value.substring(separator + 2));
      if (page == null) continue;
      result.putIfAbsent(bookId, () => <int>[]).add(page);
    }
    for (final pages in result.values) {
      pages.sort();
    }
    return result;
  }

  static Future<({int chapter, Duration position})> audioFor(
    String bookId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      chapter: prefs.getInt(_audioChapterKey(bookId)) ?? 0,
      position: Duration(
        milliseconds: prefs.getInt(_audioPositionKey(bookId)) ?? 0,
      ),
    );
  }

  static Future<void> saveAudio(
    String bookId,
    int chapter,
    Duration position,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_audioChapterKey(bookId), chapter);
    await prefs.setInt(_audioPositionKey(bookId), position.inMilliseconds);
  }
}
