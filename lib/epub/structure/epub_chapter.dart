import '../content/html_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import 'epub_page.dart';
import 'line.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter {
  final int chapterNumber;
  final List<EpubPage> pages = [];
  bool paragraph = false;
  double lastHeight = 0;

  EpubChapter({required this.chapterNumber,});

  EpubPage? operator [](int index) => pages.elementAtOrNull(index);

  int get lastPageIndex => pages.length - 1;

  void addContentToCurrentPage(HtmlContent content) {
    if (pages.isEmpty) {
      pages.add(EpubPage());
    }

    if (pages.last.getActiveLines().isNotEmpty && pages.last.currentLine!.height > 0) {
      lastHeight = pages.last.currentLine!.height;
    }

    if (content is ParagraphBreak) {
      if (pages.last.getActiveLines().isNotEmpty) {
        pages.last.currentLine?.completeParagraph();
      }
      pages.last.addLine(paragraph: true, margin: content.margin, blockStyle: content.blockStyle, dropCapsIndent: pages.last.dropCapsXPosition);
      paragraph = true;
    } if (content is LineBreak) {
      // So, the first <br> tag completes the current line if it isn't empty, or adds a line if it is empty. If we have
      // subsequent <br> tags after this, they each add a new line in!
      if (pages.last.currentLine!.elements.isNotEmpty) {
        pages.last.currentLine?.completeParagraph();
        pages.last.addLine(paragraph: true, margin: 0, blockStyle: content.blockStyle, dropCapsIndent: pages.last.dropCapsXPosition);
      } else {
        pages.last.addLine(paragraph: true, margin: lastHeight, blockStyle: content.blockStyle, dropCapsIndent: pages.last.dropCapsXPosition);
      }
    } else {
      // Reset alignment based on this content if we are adding content to an empty line.
      if (pages.last.isCurrentLineEmpty && content.blockStyle.alignment != null) {
        pages.last.currentLine?.alignment = content.blockStyle.alignment!;
      }
      List<Line> overflow = pages.last.addElement(content, content is LinkContent ? content.footnotes : [], paragraph: paragraph);
      paragraph = false;
      while (overflow.isNotEmpty) {
        EpubPage previousPage = pages.last;
        pages.add(EpubPage());
        pages.last.dropCapsXPosition = previousPage.dropCapsXPosition;
        pages.last.dropCapsYPosition = previousPage.dropCapsYPosition;

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