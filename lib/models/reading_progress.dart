import 'package:injectable/injectable.dart';

@lazySingleton
class ReadingProgress {
  String book;
  int fontSize;
  int chapterNumber;
  int pageNumber;

  ReadingProgress() : book = "", chapterNumber = 0, pageNumber = 1, fontSize = 12;

  ReadingProgress copyWith({required String book, required int fontSize, required int chapterNumber, required int pageNumber}) {
    ReadingProgress progress = ReadingProgress();
    progress.book          = book;
    progress.fontSize      = fontSize;
    progress.chapterNumber = chapterNumber;
    progress.pageNumber    = pageNumber;

    return progress;
  }

  static ReadingProgress fromMap(Map<String, dynamic> progress) {
    ReadingProgress rp = ReadingProgress();
    rp.book          = progress['path'];
    rp.fontSize      = progress['fontSize'];
    rp.chapterNumber = progress['chapterNumber'];
    rp.pageNumber    = progress['pageNumber'];

    return rp;
  }

  Map<String, dynamic> toMap() {
    return {
      'path'          : book,
      'fontSize'      : fontSize,
      'chapterNumber' : chapterNumber,
      'pageNumber'    : pageNumber,
    };
  }

  @override
  String toString() {
    return '$book: chapter: $chapterNumber / page: $pageNumber';
  }
}