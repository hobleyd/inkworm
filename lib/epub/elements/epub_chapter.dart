import 'package:inkworm/epub/content/margin_content.dart';
import 'package:inkworm/epub/content/paragraph_break.dart';
import 'package:inkworm/epub/styles/block_style.dart';

import '../content/html_content.dart';
import 'epub_page.dart';
import 'line.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter {
  final int chapterNumber;
  bool newParagraphRequired = false;

  final List<EpubPage> pages = [];

  EpubChapter({required this.chapterNumber,});

  EpubPage? operator [](int index) => pages[index];

  int get lastPageIndex => pages.length - 1;

  void addContentToCurrentPage(HtmlContent content) {
    if (pages.isEmpty) {
      pages.add(EpubPage());
    }

    if (content is ParagraphBreak) {
      if (pages.last.getActiveLines().isNotEmpty) {
        pages.last.currentLine?.completeParagraph();
        pages.last.currentLine?.completeLine();
      }
      newParagraphRequired = true;
    } if (content is MarginContent) {
      pages.last.addLine(paragraph: false, margin: content.margin, blockStyle: content.blockStyle);
    } else {
      if (pages.last.isCurrentLineEmpty && content.blockStyle.alignment != null) {
        pages.last.currentLine?.alignment = content.blockStyle.alignment!;
      }
      List<Line> overflow = pages.last.addElement(newParagraphRequired, content, []);
      if (overflow.isNotEmpty) {
        pages.add(EpubPage());
        pages.last.addLines(overflow);
      }
      newParagraphRequired = false;
    }
  }

  void clear() {
    for (var page in pages) {
      page.clear();
    }

    pages.clear();
  }
}