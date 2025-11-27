import 'package:flutter/foundation.dart';
import 'package:inkworm/epub/constants.dart';

import '../content/html_content.dart';
import '../content/paragraph_break.dart';
import '../content/text_content.dart';
import 'epub_page.dart';
import 'line.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter {
  final int chapterNumber;
  final List<EpubPage> pages = [];
  bool paragraph = false;

  EpubChapter({required this.chapterNumber,});

  EpubPage? operator [](int index) => pages.elementAtOrNull(index);

  int get lastPageIndex => pages.length - 1;

  void addContentToCurrentPage(HtmlContent content) {
    if (pages.isEmpty) {
      pages.add(EpubPage());
    }

    if (content is ParagraphBreak) {
      if (pages.last.getActiveLines().isNotEmpty) {
        pages.last.currentLine?.completeParagraph();
      }
      pages.last.addLine(paragraph: true, margin: content.margin, blockStyle: content.blockStyle, dropCapsIndent: pages.last.dropCapsXPosition);
      paragraph = true;
    } else {
      // Reset alignment based on this content if we are adding content to an empty line.
      if (pages.last.isCurrentLineEmpty && content.blockStyle.alignment != null) {
        pages.last.currentLine?.alignment = content.blockStyle.alignment!;
      }
      List<Line> overflow = pages.last.addElement(content, [], paragraph: paragraph);
      paragraph = false;
      while (overflow.isNotEmpty) {
        double dropCapsXPos = pages.last.dropCapsXPosition;
        double dropCapsYPos = pages.last.dropCapsYPosition;
        pages.add(EpubPage());
        pages.last.dropCapsXPosition = dropCapsXPos;
        pages.last.dropCapsYPosition = dropCapsYPos;

        overflow = pages.last.addOverflow(overflow);
      }
    }
  }

  void clear() {
    for (var page in pages) {
      page.clear();
    }

    pages.clear();
  }
}