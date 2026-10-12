import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

/// Document-local text index. Never uploads text or changes the PDF.
class PdfSearchService extends ChangeNotifier {
  final Map<int, PdfPageText> _pages = {};
  List<PdfPageTextRange> matches = [];
  bool indexing = true;
  bool incomplete = false;
  bool _disposed = false;
  int _generation = 0;
  String query = '';
  bool get hasText => _pages.values.any((p) => p.fullText.trim().isNotEmpty);

  Future<void> index(int count, Future<PdfPageText?> Function(int) load) async {
    final generation = ++_generation;
    for (var page = 1; page <= count; page++) {
      if (_disposed || generation != _generation) return;
      try {
        final text = await load(page);
        if (_disposed || generation != _generation) return;
        if (text != null) _pages[page] = text;
      } catch (_) {
        if (_disposed || generation != _generation) return;
        incomplete = true;
      }
      _find();
      notifyListeners();
      // Yield to scrolling/painting between pages, including cached documents.
      await Future<void>.delayed(Duration.zero);
    }
    if (_disposed || generation != _generation) return;
    indexing = false;
    notifyListeners();
  }

  void search(String value) {
    query = value.trim();
    _find();
    notifyListeners();
  }

  void _find() {
    if (query.isEmpty) {
      matches = [];
      return;
    }
    final pattern = RegExp(
        query.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+'),
        caseSensitive: false,
        unicode: true);
    matches = [
      for (final page in _pages.values)
        for (final match in pattern.allMatches(page.fullText))
          PdfPageTextRange(pageText: page, start: match.start, end: match.end),
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pages.clear();
    super.dispose();
  }
}
