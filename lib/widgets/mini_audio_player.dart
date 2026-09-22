import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../services/audiobook_audio_handler.dart';
import '../screens/reader_screen.dart';
import 'app_glass.dart';

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final handler = AudiobookAudioHandler.current;
    if (handler == null) return const SizedBox.shrink();
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      initialData: handler.playbackState.value,
      builder: (context, snapshot) {
        final state = snapshot.data!;
        final book = handler.book;
        if (book == null ||
            state.processingState == AudioProcessingState.idle) {
          return const SizedBox.shrink();
        }
        final loading = state.processingState == AudioProcessingState.loading;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: AppGlass(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                const Icon(Icons.graphic_eq_rounded),
                const SizedBox(width: 8),
                Expanded(
                    child: InkWell(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => ReaderScreen(book: book))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(book.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(handler.mediaItem.value?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                )),
                IconButton(
                  tooltip: state.playing ? 'Pause audio' : 'Play audio',
                  onPressed: loading
                      ? null
                      : (state.playing ? handler.pause : handler.play),
                  icon: Icon(state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                ),
                IconButton(
                    tooltip: 'Stop audio',
                    onPressed: handler.stop,
                    icon: const Icon(Icons.stop_rounded)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
