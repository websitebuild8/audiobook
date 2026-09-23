import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktaba_athariyya/models/book.dart';
import 'package:maktaba_athariyya/services/audiobook_audio_handler.dart';
import 'package:maktaba_athariyya/services/download_service.dart';
import 'package:maktaba_athariyya/widgets/audio_player_sheet.dart';

import 'audiobook_audio_handler_test.dart' show FakePlayer, WidgetAudioHandler;

final chapters = Book(
    id: 'sheet',
    title: 'Audiobook',
    category: 'Test',
    pdfAsset: '/book.pdf',
    audio: List.generate(
        12,
        (i) => AudioChapter(
            title: 'Chapter ${i + 1}',
            assetPath: 'https://example.com/$i.mp3',
            fileSize: 5 * 1024 * 1024)));

class SheetDownloads extends ChangeNotifier implements DownloadService {
  final requested = <int>[];
  @override
  Future<void> ensureState(Book book) async {}
  @override
  BookDownloadState chapterStateFor(Book book, int index) => BookDownloadState(
      status: requested.contains(index)
          ? BookDownloadStatus.downloading
          : BookDownloadStatus.notDownloaded,
      totalBytes: 100,
      downloadedBytes: 25);
  @override
  Future<void> downloadChapter(Book book, int index) async {
    requested.add(index);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'sheet expands, scrolls all chapters and downloads only the selected file',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    late WidgetAudioHandler handler;
    await tester.runAsync(() async {
      handler = WidgetAudioHandler(FakePlayer());
      AudiobookAudioHandler.current = handler;
    });
    final downloads = SheetDownloads();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AudioPlayerSheet(
                            book: chapters, downloads: downloads)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('audio-draggable-sheet'));
    final before =
        tester.getSize(find.byKey(const ValueKey('audio-sheet-list'))).height;
    await tester.dragFrom(
        tester.getTopLeft(find.byKey(const ValueKey('audio-sheet-handle'))) +
            const Offset(20, 2),
        const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const ValueKey('audio-sheet-list'))).height,
        greaterThan(before));
    await tester
        .ensureVisible(find.byKey(const ValueKey('download-chapter-1')));
    await tester.tap(find.byKey(const ValueKey('download-chapter-1')));
    await tester.pump();
    expect(downloads.requested, [1]);
    expect(find.text('5.0 MB · 25%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('12. Chapter 12'), 240,
        scrollable: find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .first);
    expect(find.text('12. Chapter 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => handler.dispose());
    downloads.dispose();
    AudiobookAudioHandler.current = null;
  });

  testWidgets('collapsing the modal keeps background playback running',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    late FakePlayer player;
    late WidgetAudioHandler handler;
    await tester.runAsync(() async {
      player = FakePlayer();
      handler = WidgetAudioHandler(player);
      AudiobookAudioHandler.current = handler;
      await handler.playBook(chapters);
    });
    final downloads = SheetDownloads();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AudioPlayerSheet(
                            book: chapters, downloads: downloads)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.dragFrom(
        tester.getTopLeft(find.byKey(const ValueKey('audio-sheet-handle'))) +
            const Offset(20, 2),
        const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byType(AudioPlayerSheet), findsNothing);
    expect(player.playing, isTrue);
    expect(player.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => handler.dispose());
    downloads.dispose();
    AudiobookAudioHandler.current = null;
  });
}
