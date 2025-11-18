import 'package:inkworm/epub/content/paragraph_break.dart';

import '../content/html_content.dart';
import 'epub_page.dart';
import 'line.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter {
  final int chapterNumber;
  bool newParagraphRequired = false;
  double lastParagraphBottomMargin = 0;

  final List<EpubPage> pages = [];

  EpubChapter({required this.chapterNumber,});

  EpubPage? operator [](int index) => pages[index];

  int get lastPageIndex => pages.length - 1;

  void addContentToCurrentPage(HtmlContent content) {
    if (pages.isEmpty) {
      pages.add(EpubPage());
    }

    // If I get a ParagraphBreak, I need to move the next line down by the bottom-margin of the
    // ParagraphBreak BlockStyle and the top margin of the new BlockStyle.
    if (content is ParagraphBreak) {
      if (pages.last.getActiveLines().isNotEmpty) {
        pages.last.getActiveLines().last.completeParagraph();
      }
      newParagraphRequired = true;
      lastParagraphBottomMargin = content.blockStyle.marginBottom;
    } else {
      List<Line> overflow = pages.last.addElement(newParagraphRequired, lastParagraphBottomMargin, content, []);
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