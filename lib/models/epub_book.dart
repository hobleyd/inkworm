import 'package:freezed_annotation/freezed_annotation.dart';

import '../epub/elements/epub_chapter.dart';
import 'manifest_item.dart';

part 'epub_book.freezed.dart';

@freezed
class EpubBook with _$EpubBook {
  @override
  String author;

  @override
  String title;

  @override
  List<EpubChapter> chapters;

  @override
  Map<String, ManifestItem> manifest;

  @override
  StackTrace? error;

  @override
  bool parsingBook;

  EpubChapter operator [](int index) => chapters[index];

  int get lastChapterIndex => chapters.length - 1;
  int get totalPages => chapters.fold(0, (sum, chapter) => sum + chapter.pages.length);

  EpubBook({required this.author, required this.title, this.error, required this.chapters, required this.manifest, required this.parsingBook});

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