import 'package:injectable/injectable.dart';

@lazySingleton
class ReadingProgress {
  String book;
  int chapterNumber;
  int pageNumber;

  ReadingProgress() : book = "", chapterNumber = 0, pageNumber = 1;

  ReadingProgress copyWith({required String book, required int chapterNumber, required int pageNumber}) {
    ReadingProgress progress = ReadingProgress();
    progress.book          = book;
    progress.chapterNumber = chapterNumber;
    progress.pageNumber    = pageNumber;

    return progress;
  }

  @override
  String toString() {
    return '$book: chapter: $chapterNumber / page: $pageNumber';
  }
}