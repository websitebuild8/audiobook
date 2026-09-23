import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktaba_athariyya/models/book.dart';
import 'package:maktaba_athariyya/services/audiobook_audio_handler.dart';
import 'package:maktaba_athariyya/services/progress_service.dart';
import 'package:maktaba_athariyya/widgets/audio_player_panel.dart';

const book = Book(
    id: 'audio',
    title: 'Book',
    category: 'Test',
    pdfAsset: '/book.pdf',
    audio: [
      AudioChapter(title: 'Chapter one', assetPath: '/one.mp3'),
      AudioChapter(title: 'Chapter two', assetPath: '/two.mp3')
    ]);
const other = Book(
    id: 'other',
    title: 'Other book',
    category: 'Test',
    pdfAsset: '/other.pdf',
    audio: [AudioChapter(title: 'Other audio', assetPath: '/other.mp3')]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlayer player;
  late AudiobookAudioHandler handler;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = FakePlayer();
    handler = AudiobookAudioHandler(player: player);
    AudiobookAudioHandler.current = handler;
  });
  tearDown(() async {
    if (!player.disposed) await handler.dispose();
    AudiobookAudioHandler.current = null;
  });

  test(
      'restores progress and exposes the complete chapter queue to system controls',
      () async {
    await ProgressService.saveAudio(book.id, 1, const Duration(seconds: 42));
    await handler.playBook(book);
    await Future<void>.delayed(Duration.zero);
    expect(player.currentIndex, 1);
    expect(player.position.inSeconds, 42);
    expect(player.playing, true);
    expect(handler.queue.value.map((item) => item.title),
        ['Chapter one', 'Chapter two']);
    expect(handler.mediaItem.value?.album, 'Book');
    expect(handler.playbackState.value.controls, contains(MediaControl.stop));
    await handler.rewind();
    expect(player.position.inSeconds, 32);
    await handler.fastForward();
    expect(player.position.inSeconds, 62);
    await handler.pause();
    expect(player.playing, false);
    expect((await ProgressService.audioFor(book.id)).position.inSeconds, 62);
    await handler.play();
    await handler.stop();
    expect(player.playing, false);
    expect(
        handler.playbackState.value.processingState, AudioProcessingState.idle);
  });

  testWidgets(
      'leaving or opening another reader does not stop or replace playback',
      (tester) async {
    await tester.runAsync(() async {
      await handler.dispose();
      player = FakePlayer();
      // Persistence is covered by the service tests. Avoid mixing real and
      // widget-test clocks for preferences futures in this ownership test.
      handler = WidgetAudioHandler(player);
      AudiobookAudioHandler.current = handler;
      await handler.playBook(book);
    });
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AudioPlayerPanel(book: book))));
    await tester.pump();
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AudioPlayerPanel(book: other))));
    await tester.pump();
    expect(handler.book?.id, book.id);
    expect(player.playing, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(player.playing, true);
    expect(player.disposed, false);
    await tester.runAsync(() => handler.dispose());
  });

  test(
      'selecting a chapter starts that chapter and refreshing local sources preserves progress',
      () async {
    var downloaded = false;
    await handler.dispose();
    player = FakePlayer();
    handler = AudiobookAudioHandler(
        player: player,
        resolveBook: (next) async => downloaded
            ? next.copyWithLocalMedia(
                pdfPath: next.pdfAsset,
                audioPaths: ['/offline/one.mp3', '/offline/two.mp3'])
            : next);
    await handler.playBook(book, chapterIndex: 1);
    expect(player.currentIndex, 1);
    expect(player.position, Duration.zero);
    await handler.seek(const Duration(seconds: 45));
    downloaded = true;
    await handler.playBook(book);
    expect(handler.book!.audio[1].assetPath, '/offline/two.mp3');
    expect(player.currentIndex, 1);
    expect(player.position.inSeconds, 45);
    await handler.playBook(book, chapterIndex: 0);
    expect(player.currentIndex, 0);
    expect(player.position, Duration.zero);
  });

  test('stop during loading prevents delayed automatic playback', () async {
    player.loadGate = Completer<void>();
    final loading = handler.playBook(book);
    await player.loadStarted.future;
    await handler.stop();
    player.loadGate!.complete();
    await loading;
    expect(player.playing, false);
    expect(player.playCalls, 0);
  });

  test('switching books preserves separate positions and replaces the queue',
      () async {
    await handler.playBook(book);
    await handler.seek(const Duration(seconds: 23));
    await handler.playBook(other);
    expect((await ProgressService.audioFor(book.id)).position.inSeconds, 23);
    expect(handler.queue.value.length, 1);
    expect(handler.book?.id, other.id);
    await handler.playBook(book);
    expect(player.position.inSeconds, 23);
  });

  test(
      'background task removal continues playing; completion stops and replay restarts',
      () async {
    await handler.playBook(book);
    await handler.onTaskRemoved();
    expect(player.playing, true);
    player.completeBook();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(player.playing, false);
    await handler.play();
    expect(player.currentIndex, 0);
    expect(player.position, Duration.zero);
    expect(player.playing, true);
  });
}

class FakePlayer implements AudioPlayer {
  final events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final indices = StreamController<int?>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  Completer<void>? loadGate;
  final loadStarted = Completer<void>();
  bool disposed = false;
  int playCalls = 0;
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  int? currentIndex;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(minutes: 5);
  @override
  double speed = 1;
  @override
  AudioSource? audioSource;
  @override
  Duration get bufferedPosition => duration!;
  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<int?> get currentIndexStream => indices.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  void emit() {
    states.add(PlayerState(playing, processingState));
    events.add(PlaybackEvent());
  }

  @override
  Future<Duration?> setAudioSources(List<AudioSource> sources,
      {bool preload = true,
      int? initialIndex,
      Duration? initialPosition,
      ShuffleOrder? shuffleOrder}) async {
    if (!loadStarted.isCompleted) loadStarted.complete();
    if (loadGate != null) await loadGate!.future;
    audioSource = sources.first;
    currentIndex = initialIndex ?? 0;
    position = initialPosition ?? Duration.zero;
    processingState = ProcessingState.ready;
    indices.add(currentIndex);
    emit();
    return duration;
  }

  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
    processingState = ProcessingState.ready;
    emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    emit();
  }

  @override
  Future<void> stop() async {
    playing = false;
    processingState = ProcessingState.idle;
    emit();
  }

  @override
  Future<void> seek(Duration? value, {int? index}) async {
    position = value ?? Duration.zero;
    if (index != null) {
      currentIndex = index;
      indices.add(index);
    }
    emit();
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
    emit();
  }

  void completeBook() {
    currentIndex = 1;
    position = duration!;
    processingState = ProcessingState.completed;
    emit();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
    await states.close();
    await indices.close();
    await durations.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class WidgetAudioHandler extends AudiobookAudioHandler {
  WidgetAudioHandler(AudioPlayer player) : super(player: player);
  @override
  Future<void> saveProgress() async {}
}
