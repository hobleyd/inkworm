import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:inkworm/epub/epub_chapter.dart';
import 'package:inkworm/models/manifest_item.dart';

part 'epub_book.freezed.dart';

@freezed
class EpubBook with _$EpubBook {
  String author;
  String title;
  List<EpubChapter> chapters;
  Map<String, ManifestItem> manifest;
  StackTrace? error;

  EpubChapter operator [](int index) => chapters[index];

  EpubBook({required this.author, required this.title, this.error, required this.chapters, required this.manifest});
}