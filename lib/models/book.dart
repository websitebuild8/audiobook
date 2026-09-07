class AudioChapter {
  const AudioChapter({
    required this.title,
    required this.assetPath,
    this.fileSize = 0,
  });

  final String title;
  final String assetPath;
  final int fileSize;

  AudioChapter copyWithSource(String source) => AudioChapter(
        title: title,
        assetPath: source,
        fileSize: fileSize,
      );
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.category,
    required this.pdfAsset,
    this.pdfFileSize = 0,
    this.coverAsset,
    this.audio = const [],
  });

  final String id;
  final String title;
  final String category;
  final String pdfAsset;
  final int pdfFileSize;
  final String? coverAsset;
  final List<AudioChapter> audio;

  bool get hasAudio => audio.isNotEmpty;
  int get totalDownloadSize =>
      pdfFileSize + audio.fold(0, (total, item) => total + item.fileSize);

  Book copyWithLocalMedia({
    required String pdfPath,
    required List<String> audioPaths,
  }) {
    return Book(
      id: id,
      title: title,
      category: category,
      pdfAsset: pdfPath,
      pdfFileSize: pdfFileSize,
      coverAsset: coverAsset,
      audio: [
        for (var index = 0; index < audio.length; index++)
          audio[index].copyWithSource(audioPaths[index]),
      ],
    );
  }
}
