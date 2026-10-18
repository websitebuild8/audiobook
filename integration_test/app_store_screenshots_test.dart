import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maktaba_athariyya/main.dart' as app;
import 'package:maktaba_athariyya/screens/library_screen.dart';
import 'package:maktaba_athariyya/screens/reader_screen.dart';
import 'package:maktaba_athariyya/services/catalog_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture real iPad screens for the App Store', (tester) async {
    Future<void> waitFor(bool Function() ready, String label) async {
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError(
              'Timed out waiting for $label; no placeholder capture.');
        }
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.pump(const Duration(seconds: 2));
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'UI error before $name');
      await binding.takeScreenshot(name);
    }

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final prefs = await SharedPreferences.getInstance();
    await prefs
        .clear(); // Isolated simulator only; never run against a user device.
    await prefs.setBool('dark_mode', false);
    final books = await CatalogService.load(refresh: true);
    expect(books, isNotEmpty, reason: 'The live catalogue must be available.');
    final audioBooks = books.where((book) => book.hasAudio).toList();
    expect(audioBooks, isNotEmpty,
        reason: 'An audiobook is needed for captures.');
    final book = audioBooks.first;
    await app.main();
    await waitFor(
        () => find.byType(TextField).evaluate().isNotEmpty, 'library');

    // Preload actual covers rather than capturing image-loading placeholders.
    final context = tester.element(find.byType(LibraryScreen));
    await Future.wait(
        books.take(12).where((b) => b.coverAsset != null).map((b) {
      return precacheImage(NetworkImage(b.coverAsset!), context);
    })).timeout(const Duration(seconds: 60));

    for (final mode in ['light', 'dark']) {
      if (mode == 'dark') {
        final library =
            tester.widget<LibraryScreen>(find.byType(LibraryScreen));
        library.onToggleTheme();
        await tester.pump(const Duration(seconds: 2));
      }
      await capture('01-library-$mode');
      final scroll = find.byType(CustomScrollView).first;
      await tester.drag(scroll, const Offset(0, -650));
      await tester.pump(const Duration(seconds: 2));
      await capture('02-books-$mode');
      await tester.drag(scroll, const Offset(0, 2000));
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.byKey(const ValueKey('navigation-tab-1')));
      await tester.pump(const Duration(seconds: 2));
      await capture('03-audiobooks-$mode');
      await tester.tap(find.byKey(const ValueKey('navigation-tab-0')));
      await tester.pump(const Duration(seconds: 2));

      final navigator =
          Navigator.of(tester.element(find.byType(LibraryScreen)));
      unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(book: book, initialPage: 1),
      )));
      await waitFor(() {
        final viewers = find.byType(PdfViewer).evaluate();
        if (viewers.isEmpty) return false;
        return (viewers.first.widget as PdfViewer).controller?.isReady == true;
      }, 'PDF document');
      // Allow any opt-in reader notice to disappear naturally.
      await tester.pump(const Duration(seconds: 31));
      await capture('04-reader-$mode');
      await tester.tap(find.byTooltip('Expand audio player'));
      await waitFor(
          () => find
              .byKey(const ValueKey('audio-sheet-handle'))
              .evaluate()
              .isNotEmpty,
          'audio player');
      await tester.drag(find.byKey(const ValueKey('audio-sheet-handle')),
          const Offset(0, -700));
      await tester.pump(const Duration(seconds: 2));
      await capture('05-audio-player-$mode');
      await tester.tap(find.byTooltip('Collapse audio player'));
      await tester.pump(const Duration(seconds: 1));
      navigator.pop();
      await tester.pump(const Duration(seconds: 2));
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
