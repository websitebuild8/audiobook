import 'package:shared_preferences/shared_preferences.dart';

abstract final class ProgressService {
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
