import 'package:get_it/get_it.dart';
import 'package:json_annotation/json_annotation.dart';

import '../content/html_content.dart';

import 'build_page.dart';
import 'page.dart';
import 'page_listener.dart';

part 'epub_chapter.g.dart';

/*
 * A Chapter contains a list of Pages
 */
@JsonSerializable()
class EpubChapter implements PageListener {
  final int chapterNumber;

  @JsonKey(ignore: true)
  final List<Page> pages = [];

  EpubChapter({required this.chapterNumber,});

  factory EpubChapter.fromJson(Map<String, dynamic> json) => _$EpubChapterFromJson(json);
  Map<String, dynamic> toJson() => _$EpubChapterToJson(this);

  Page? operator [](int index) => pages.elementAtOrNull(index);

  int get lastPageIndex => pages.length - 1;

  void addContent(List<HtmlContent> elements) {
    BuildPage buildPage = GetIt.instance.get<BuildPage>();
    buildPage.pageListener = this;
    buildPage.addContent(elements);
    buildPage.pageListener = null;
  }

  @override
  void addPage(Page page) {
    pages.add(page);
  }

  @override
  String toString() {
    return '{chapter: $chapterNumber, pages: ${pages.length}}';
  }
}
