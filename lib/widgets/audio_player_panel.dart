import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/book.dart';
import '../services/audiobook_audio_handler.dart';

class AudioPlayerPanel extends StatefulWidget {
  const AudioPlayerPanel({super.key, required this.book});
  final Book book;

  @override
  State<AudioPlayerPanel> createState() => _AudioPlayerPanelState();
}

class _AudioPlayerPanelState extends State<AudioPlayerPanel> {
  final _handler = AudiobookAudioHandler.instance;
  StreamSubscription<dynamic>? _subscription;
  bool _requesting = false;
  bool get _active => _handler.book?.id == widget.book.id;
  AudioPlayer get _player => _handler.player;
  int get _chapter => _active ? _handler.chapter : 0;
  bool get _loading => _requesting || (_active && _handler.loading);
  double get _speed => _player.speed;

  @override
  void initState() {
    super.initState();
    _subscription = _handler.playbackState.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _togglePlay() async {
    if (_active && _player.playing) {
      await _handler.pause();
      return;
    }
    setState(() => _requesting = true);
    try {
      await _handler.playBook(widget.book);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('އޯޑިއޯ ލޯޑު ނުކުރެވުނު')));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _changeChapter(int delta) =>
      _handler.skipToQueueItem(_chapter + delta);
  Future<void> _seekRelative(int seconds) => _handler.seekRelative(seconds);
  Future<void> _cycleSpeed() async {
    const speeds = [1.0, 1.25, 1.5, 2.0, .75];
    await _handler
        .setSpeed(speeds[(speeds.indexOf(_speed) + 1) % speeds.length]);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // Playback belongs to the app and continues after leaving this screen.
    unawaited(_handler.saveProgress());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.book.audio[_chapter];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${_chapter + 1} / ${widget.book.audio.length}',
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Stop audio',
                    onPressed: _active ? _handler.stop : null,
                    icon: const Icon(Icons.stop_rounded),
                  ),
                  TextButton(
                    onPressed: _active ? _cycleSpeed : null,
                    child: Text(
                      '${_formatSpeed(_speed)}×',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'sans-serif',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = _active ? _player.position : Duration.zero;
                  final duration = _active
                      ? (_player.duration ?? Duration.zero)
                      : Duration.zero;
                  final max = duration.inMilliseconds <= 0
                      ? 1.0
                      : duration.inMilliseconds.toDouble();
                  final value =
                      position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: value,
                            max: max,
                            onChanged: duration == Duration.zero
                                ? null
                                : (next) => _handler.seek(
                                      Duration(milliseconds: next.round()),
                                    ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: _timeStyle,
                            ),
                            Text(
                              _formatDuration(duration),
                              style: _timeStyle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _active && !_loading && _chapter > 0
                          ? () => _changeChapter(-1)
                          : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    IconButton(
                      onPressed: _active && !_loading
                          ? () => _seekRelative(-10)
                          : null,
                      icon: const Icon(Icons.replay_10_rounded),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = _active && _player.playing;
                        return IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(52, 52),
                          ),
                          onPressed: _loading ? null : _togglePlay,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 30,
                                ),
                        );
                      },
                    ),
                    IconButton(
                      onPressed:
                          _active && !_loading ? () => _seekRelative(30) : null,
                      icon: const Icon(Icons.forward_30_rounded),
                    ),
                    IconButton(
                      onPressed: _active &&
                              !_loading &&
                              _chapter < widget.book.audio.length - 1
                          ? () => _changeChapter(1)
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _timeStyle = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 11,
    color: Color(0xFF91A09A),
  );

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatSpeed(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}
