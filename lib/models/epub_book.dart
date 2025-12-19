import 'package:freezed_annotation/freezed_annotation.dart';

import '../epub/structure/epub_chapter.dart';

part 'epub_book.freezed.dart';

@freezed
class EpubBook with _$EpubBook {
  @override
  String uri;

  @override
  String author;

  @override
  String title;

  @override
  List<EpubChapter> chapters;

  @override
  StackTrace? error;

  @override
  String? errorDescription;

  @override
  bool parsingBook;

  EpubChapter operator [](int index) => chapters[index];

  int get lastChapterIndex => chapters.length - 1;
  int get totalPages => chapters.fold(0, (sum, chapter) => sum + chapter.pages.length);

  EpubBook({required this.uri, required this.author, required this.title, this.error, this.errorDescription, required this.chapters, required this.parsingBook});

  int currentPageNumber(int chapterNumber, int pageNumber) {
    return chapterNumber == 0
        ? pageNumber + 1
        : chapters.sublist(0, chapterNumber).fold(0, (sum, chapter) => sum + chapter.pages.length) + pageNumber + 1;
  }

  int nextChapterPageNumber(int chapterNumber) {
    return chapterNumber == lastChapterIndex
        ? totalPages
        : chapters.sublist(0, chapterNumber+1).fold(0, (sum, chapter) => sum + chapter.pages.length);
  }
}