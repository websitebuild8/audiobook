import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/audiobook_audio_handler.dart';
import '../services/download_service.dart';
import 'app_glass.dart';
import 'audio_player_panel.dart';

Future<void> showAudioPlayerSheet(BuildContext context, Book book) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .32),
      builder: (_) => AudioPlayerSheet(book: book),
    );

/// Tapping or pulling up expands the same player without restarting playback.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({super.key, required this.book});
  final Book book;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  double _drag = 0;
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    await showAudioPlayerSheet(context, widget.book);
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final handler = AudiobookAudioHandler.instance;
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      initialData: handler.playbackState.value,
      builder: (context, snapshot) {
        final active = handler.book?.id == widget.book.id;
        final playing = active && (snapshot.data?.playing ?? false);
        return GestureDetector(
          onVerticalDragStart: (_) => _drag = 0,
          onVerticalDragUpdate: (details) => _drag += details.delta.dy,
          onVerticalDragEnd: (_) {
            if (_drag < -20) unawaited(_open());
          },
          child: AppGlass(
              child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _open,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(99))),
                  Row(children: [
                    const Icon(Icons.headphones_rounded, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(widget.book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(
                              active
                                  ? (handler.mediaItem.value?.title ?? '')
                                  : '${widget.book.audio.length} އޯޑިއޯ ބައި',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ])),
                    IconButton(
                        tooltip: playing ? 'Pause audio' : 'Play audio',
                        onPressed: active && handler.loading
                            ? null
                            : () async {
                                try {
                                  if (playing) {
                                    await handler.pause();
                                  } else {
                                    await handler.playBook(widget.book);
                                  }
                                } catch (_) {
                                  if (context.mounted) _showAudioError(context);
                                }
                              },
                        icon: Icon(playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded)),
                    if (active)
                      IconButton(
                          tooltip: 'Stop audio',
                          onPressed: handler.stop,
                          icon: const Icon(Icons.stop_rounded)),
                    IconButton(
                        tooltip: 'Expand audio player',
                        onPressed: _open,
                        icon: const Icon(Icons.keyboard_arrow_up_rounded)),
                  ]),
                ]),
              ),
            ),
          )),
        );
      },
    );
  }
}

class AudioPlayerSheet extends StatefulWidget {
  const AudioPlayerSheet({super.key, required this.book, this.downloads});
  final Book book;
  final DownloadService? downloads;

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet> {
  late final _downloads = widget.downloads ?? DownloadService.instance;
  final _handler = AudiobookAudioHandler.instance;
  int? _startingChapter;

  @override
  void initState() {
    super.initState();
    unawaited(_downloads.ensureState(widget.book));
  }

  Future<void> _playChapter(int index) async {
    setState(() => _startingChapter = index);
    try {
      if (_handler.book?.id == widget.book.id && _handler.chapter == index) {
        if (_handler.player.playing) {
          await _handler.pause();
        } else {
          await _handler.playBook(widget.book);
        }
      } else {
        await _handler.playBook(widget.book, chapterIndex: index);
      }
    } catch (_) {
      if (mounted) _showAudioError(context);
    } finally {
      if (mounted) setState(() => _startingChapter = null);
    }
  }

  Future<void> _download(int index) async {
    try {
      await _downloads.downloadChapter(widget.book, index);
    } catch (_) {
      if (mounted) _showAudioError(context);
    }
  }

  Future<void> _remove(int index) async {
    if (_handler.book?.id == widget.book.id && _handler.chapter == index) {
      await _handler.stop();
    }
    await _downloads.removeChapter(widget.book, index);
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        key: const ValueKey('audio-draggable-sheet'),
        initialChildSize: .72,
        minChildSize: .24,
        maxChildSize: .96,
        snap: true,
        snapSizes: const [.72],
        expand: false,
        builder: (context, scrollController) => AppGlass(
          radius: 32,
          tint: Theme.of(context).colorScheme.surface.withValues(alpha: .95),
          child: Material(
            color: Colors.transparent,
            child: StreamBuilder<PlaybackState>(
              stream: _handler.playbackState,
              initialData: _handler.playbackState.value,
              builder: (context, snapshot) => AnimatedBuilder(
                animation: _downloads,
                builder: (context, _) => ListView.builder(
                  key: const ValueKey('audio-sheet-list'),
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                      16, 10, 16, MediaQuery.paddingOf(context).bottom + 24),
                  itemCount: widget.book.audio.length + 1,
                  itemBuilder: (context, row) {
                    if (row == 0) {
                      return Column(children: [
                        Center(
                            child: Container(
                                key: const ValueKey('audio-sheet-handle'),
                                width: 42,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(99),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: .35)))),
                        Row(children: [
                          Expanded(
                              child: Text(widget.book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleLarge)),
                          IconButton(
                              tooltip: 'Collapse audio player',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded)),
                        ]),
                        const SizedBox(height: 12),
                        AudioPlayerPanel(book: widget.book),
                        const SizedBox(height: 20),
                        Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text('އޯޑިއޯ ބައިތައް',
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        const SizedBox(height: 4),
                        const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                                'އޯޑިއޯ ބައިތައް ވަކިވަކިން ޑައުންލޯޑުކުރައްވާ.')),
                        const SizedBox(height: 12),
                      ]);
                    }
                    final index = row - 1;
                    final chapter = widget.book.audio[index];
                    final state =
                        _downloads.chapterStateFor(widget.book, index);
                    final selected = _handler.book?.id == widget.book.id &&
                        _handler.chapter == index;
                    final playing =
                        selected && (snapshot.data?.playing ?? false);
                    final downloaded =
                        state.status == BookDownloadStatus.downloaded;
                    final downloading =
                        state.status == BookDownloadStatus.downloading;
                    return Container(
                      key: ValueKey('audio-chapter-$index'),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: .65)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .045),
                          borderRadius: BorderRadius.circular(20)),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsetsDirectional.only(
                              start: 10, end: 4),
                          onTap: _startingChapter == null
                              ? () => _playChapter(index)
                              : null,
                          leading: _startingChapter == index
                              ? const SizedBox.square(
                                  dimension: 26,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Icon(
                                  playing
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_outline_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 30),
                          title: Text('${index + 1}. ${chapter.title}',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text([
                            if (chapter.fileSize > 0)
                              '${(chapter.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                            if (downloaded) 'އޮފްލައިން',
                            if (state.status == BookDownloadStatus.failed)
                              'އަލުން ޖައްސަވާ',
                            if (downloading && state.progress != null)
                              '${(state.progress! * 100).round()}%',
                          ].join(' · ')),
                          trailing: downloading
                              ? SizedBox.square(
                                  dimension: 48,
                                  child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox.square(
                                            dimension: 36,
                                            child: CircularProgressIndicator(
                                                value: state.progress,
                                                strokeWidth: 2)),
                                        IconButton(
                                            tooltip: 'Cancel chapter download',
                                            onPressed: () =>
                                                _downloads.cancelChapter(
                                                    widget.book, index),
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18)),
                                      ]))
                              : IconButton(
                                  key: ValueKey('download-chapter-$index'),
                                  tooltip: downloaded
                                      ? 'Remove downloaded chapter'
                                      : 'Download chapter',
                                  onPressed: () => downloaded
                                      ? _remove(index)
                                      : _download(index),
                                  icon: Icon(downloaded
                                      ? Icons.delete_outline_rounded
                                      : state.status ==
                                              BookDownloadStatus.failed
                                          ? Icons.refresh_rounded
                                          : Icons.download_rounded),
                                  color: downloaded
                                      ? Theme.of(context).colorScheme.primary
                                      : null),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
}

void _showAudioError(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('އޯޑިއޯ ލޯޑު ނުކުރެވުނު. އަލުން ޖައްސަވާ.')));
