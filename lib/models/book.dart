class AudioChapter {
  const AudioChapter({required this.title, required this.assetPath});

  final String title;
  final String assetPath;
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.category,
    required this.pdfAsset,
    this.coverAsset,
    this.audio = const [],
  });

  final String id;
  final String title;
  final String category;
  final String pdfAsset;
  final String? coverAsset;
  final List<AudioChapter> audio;

  bool get hasAudio => audio.isNotEmpty;
}
