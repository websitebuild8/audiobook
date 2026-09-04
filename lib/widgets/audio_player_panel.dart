import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/book.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';

class AudioPlayerPanel extends StatefulWidget {
  const AudioPlayerPanel({super.key, required this.book});
  final Book book;

  @override
  State<AudioPlayerPanel> createState() => _AudioPlayerPanelState();
}

class _AudioPlayerPanelState extends State<AudioPlayerPanel>
    with WidgetsBindingObserver {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  int _chapter = 0;
  bool _loading = true;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    final saved = await ProgressService.audioFor(widget.book.id);
    _chapter = saved.chapter.clamp(0, widget.book.audio.length - 1);
    await _loadChapter(_chapter, position: saved.position);
    _positionSubscription = _player.positionStream.listen((position) {
      if (position.inSeconds % 5 == 0) {
        ProgressService.saveAudio(widget.book.id, _chapter, position);
      }
    });
  }

  Future<void> _loadChapter(
    int index, {
    Duration? position,
    bool autoPlay = false,
  }) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _player.setAsset(
        widget.book.audio[index].assetPath,
        initialPosition: position,
      );
      await _player.setSpeed(_speed);
      if (!mounted) return;
      setState(() {
        _chapter = index;
        _loading = false;
      });
      if (autoPlay) await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('އޯޑިއޯ ލޯޑު ނުކުރެވުނު')));
    }
  }

  Future<void> _changeChapter(int delta) async {
    final next = _chapter + delta;
    if (next < 0 || next >= widget.book.audio.length) return;
    await ProgressService.saveAudio(widget.book.id, _chapter, _player.position);
    await _loadChapter(next, autoPlay: true);
  }

  Future<void> _seekRelative(int seconds) async {
    final duration = _player.duration ?? Duration.zero;
    final targetMs = (_player.position.inMilliseconds + seconds * 1000).clamp(
      0,
      duration.inMilliseconds,
    );
    await _player.seek(Duration(milliseconds: targetMs));
  }

  Future<void> _cycleSpeed() async {
    const speeds = [1.0, 1.25, 1.5, 2.0, .75];
    final index = speeds.indexOf(_speed);
    final next = speeds[(index + 1) % speeds.length];
    await _player.setSpeed(next);
    setState(() => _speed = next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ProgressService.saveAudio(widget.book.id, _chapter, _player.position);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    ProgressService.saveAudio(widget.book.id, _chapter, _player.position);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.book.audio[_chapter];
    return Material(
      color: Colors.white,
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
                    decoration: const BoxDecoration(
                      color: AppTheme.mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: AppTheme.emerald,
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
                  TextButton(
                    onPressed: _cycleSpeed,
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
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = _player.duration ?? Duration.zero;
                  final max = duration.inMilliseconds <= 0
                      ? 1.0
                      : duration.inMilliseconds.toDouble();
                  final value =
                      position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                  return Column(
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
                              : (next) => _player.seek(
                                    Duration(milliseconds: next.round()),
                                  ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            textDirection: TextDirection.ltr,
                            style: _timeStyle,
                          ),
                          Text(
                            _formatDuration(duration),
                            textDirection: TextDirection.ltr,
                            style: _timeStyle,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _chapter > 0 ? () => _changeChapter(-1) : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  IconButton(
                    onPressed: () => _seekRelative(-10),
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(52, 52),
                        ),
                        onPressed: _loading
                            ? null
                            : () => playing ? _player.pause() : _player.play(),
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
                    onPressed: () => _seekRelative(30),
                    icon: const Icon(Icons.forward_30_rounded),
                  ),
                  IconButton(
                    onPressed: _chapter < widget.book.audio.length - 1
                        ? () => _changeChapter(1)
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                ],
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
    color: Color(0xFF6D807C),
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
