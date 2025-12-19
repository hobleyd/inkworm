import 'package:get_it/get_it.dart';

import '../content/html_content.dart';

import 'build_page.dart';
import 'page.dart';
import 'page_listener.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter implements PageListener {
  final int chapterNumber;
  final List<Page> pages = [];

  EpubChapter({required this.chapterNumber,});

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