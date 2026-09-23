import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../services/audiobook_audio_handler.dart';
import 'audio_player_sheet.dart';

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
        final book = handler.book;
        if (book == null ||
            snapshot.data?.processingState == AudioProcessingState.idle) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: AudioPlayerBar(book: book),
        );
      },
    );
  }
}
