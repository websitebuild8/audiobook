import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/book.dart';
import 'progress_service.dart';

/// Owned by the app, never by a reader screen.
class AudiobookAudioHandler extends BaseAudioHandler {
  AudiobookAudioHandler({AudioPlayer? player})
      : player = player ?? AudioPlayer() {
    _subscriptions.add(this.player.playbackEventStream.listen((_) {
      _broadcast();
    }, onError: (Object error, StackTrace stack) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: 'Unable to play this audio. Please try again.',
      ));
    }));
    _subscriptions.add(this.player.currentIndexStream.listen((_) {
      if (!_loading) {
        _updateItem();
        _broadcast();
        unawaited(saveProgress());
      }
    }));
    _subscriptions.add(this.player.durationStream.listen((_) => _updateItem()));
    _subscriptions.add(this.player.playerStateStream.listen((state) {
      _broadcast();
      if (!_loading && state.processingState == ProcessingState.completed) {
        _ended = true;
        unawaited(stop());
      } else if (!state.playing) {
        unawaited(saveProgress());
      }
    }));
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (this.player.playing) unawaited(saveProgress());
    });
  }

  static AudiobookAudioHandler? current;
  static AudiobookAudioHandler get instance => current!;
  static Future<void> initialize() async {
    current = await AudioService.init(
      builder: AudiobookAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.athariyyah.myapp.audio',
        androidNotificationChannelName: 'Audiobook playback',
        androidNotificationOngoing: true,
        rewindInterval: Duration(seconds: 10),
        fastForwardInterval: Duration(seconds: 30),
      ),
    );
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  final AudioPlayer player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _progressTimer;
  Book? book;
  bool _loading = false;
  bool _ended = false;
  int _intent = 0;
  Future<void> _selection = Future.value();
  Future<void> _saving = Future.value();
  int get chapter => player.currentIndex ?? 0;
  bool get loading => _loading;

  /// Merely viewing a different book must not replace the playing audiobook.
  Future<void> playBook(Book next) {
    final intent = ++_intent;
    final operation = _selection.then((_) async {
      if (intent != _intent || !next.hasAudio) return;
      if (book?.id != next.id || player.audioSource == null) {
        await saveProgress();
        _loading = true;
        await player.stop();
        book = next;
        _ended = false;
        final items = [
          for (var i = 0; i < next.audio.length; i++)
            MediaItem(
              id: '${next.id}::$i',
              album: next.title,
              title: next.audio[i].title,
              artist: 'Maktaba Athariyyah',
            ),
        ];
        queue.add(items);
        _broadcast();
        try {
          final saved = await ProgressService.audioFor(next.id);
          await player.setAudioSources([
            for (var i = 0; i < next.audio.length; i++)
              _source(next.audio[i].assetPath, items[i]),
          ],
              initialIndex: saved.chapter.clamp(0, next.audio.length - 1),
              initialPosition: saved.position);
        } catch (_) {
          book = null;
          queue.add([]);
          mediaItem.add(null);
          rethrow;
        } finally {
          _loading = false;
          _updateItem();
          _broadcast();
        }
      }
      if (intent == _intent) {
        await play();
      } else {
        await player.stop();
      }
    });
    _selection = operation.catchError((Object _) {});
    return operation;
  }

  static AudioSource _source(String path, MediaItem item) {
    if (path.startsWith('/')) return AudioSource.file(path, tag: item);
    final uri = Uri.parse(path);
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return AudioSource.uri(uri, tag: item);
    }
    return AudioSource.asset(path, tag: item);
  }

  void _updateItem() {
    if (_loading || queue.value.isEmpty) return;
    final index = chapter;
    if (index >= queue.value.length) return;
    final item = queue.value[index].copyWith(duration: player.duration);
    mediaItem.add(item);
  }

  void _broadcast() {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.setSpeed,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _loading
          ? AudioProcessingState.loading
          : switch (player.processingState) {
              ProcessingState.idle => AudioProcessingState.idle,
              ProcessingState.loading => AudioProcessingState.loading,
              ProcessingState.buffering => AudioProcessingState.buffering,
              ProcessingState.ready => AudioProcessingState.ready,
              ProcessingState.completed => AudioProcessingState.completed,
            },
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: chapter,
    ));
  }

  Future<void> saveProgress() {
    final current = book;
    if (current == null || _loading) return Future.value();
    final index = chapter;
    final position = player.position;
    _saving = _saving
        .then((_) => ProgressService.saveAudio(current.id, index, position))
        .catchError((Object error) {
      debugPrint('Audio progress could not be saved: $error');
    });
    return _saving;
  }

  @override
  Future<void> play() async {
    if (book == null || _loading) return;
    if (_ended || player.processingState == ProcessingState.completed) {
      _ended = false;
      await player.seek(Duration.zero, index: 0);
    }
    // just_audio's play future completes when playback ends, not when it starts.
    unawaited(player.play().catchError((Object error) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.error,
        errorMessage: 'Unable to play this audio. Please try again.',
      ));
    }));
  }

  @override
  Future<void> pause() async {
    ++_intent;
    await player.pause();
    await saveProgress();
  }

  @override
  Future<void> stop() async {
    ++_intent;
    await saveProgress();
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _ended = false;
    await player.seek(position);
    await saveProgress();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (_loading || index < 0 || index >= queue.value.length) return;
    _ended = false;
    await player.seek(Duration.zero, index: index);
    await saveProgress();
  }

  @override
  Future<void> skipToNext() => skipToQueueItem(chapter + 1);
  @override
  Future<void> skipToPrevious() => skipToQueueItem(chapter - 1);
  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);
  @override
  Future<void> rewind() => seekRelative(-10);
  @override
  Future<void> fastForward() => seekRelative(30);
  Future<void> seekRelative(int seconds) => seek(Duration(
      milliseconds: (player.position.inMilliseconds + seconds * 1000).clamp(0,
          player.duration?.inMilliseconds ?? player.position.inMilliseconds)));

  // Android task removal is different from explicitly pressing Stop.
  @override
  Future<void> onTaskRemoved() async {
    await saveProgress();
    if (!player.playing) await stop();
  }

  /// For app shutdown/tests only; screen disposal must never call this.
  Future<void> dispose() async {
    _progressTimer?.cancel();
    await saveProgress();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
  }
}
