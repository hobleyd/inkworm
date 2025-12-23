import 'package:injectable/injectable.dart';

import '../content/html_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import '../elements/line_element.dart';
import '../elements/separators/space_separator.dart';
import '../styles/block_style.dart';
import 'line.dart';
import 'page.dart';
import 'page_listener.dart';

@LazySingleton()
class BuildPage {
  PageListener? _pageListener;
  Page currentPage = Page();
  Line? line;

  set pageListener(PageListener? listener) => _pageListener = listener;

  void addContent(List<HtmlContent> contents) {
    // Construct a line from the elements; once complete check whether it will fit on the current page, or will require a new
    // page to sit in. Send the completed page to any listeners.
    for (HtmlContent content in contents) {
      // A Paragraph break will complete the previous line, before adding a new line for the new paragraph.
      switch (content) {
        case ParagraphBreak c: addParagraphBreak(c);
        case      LineBreak l: addLineBreak(l);
        default:               addElements(content);
      }
    }
    _pageListener?.addPage(currentPage);
    currentPage = Page();
    line = null;
  }

  // This will add a paragraph of text, line by line, to the current Page.
  void addElements(HtmlContent content,) {
    if (line!.isEmpty && content.alignment != null) {
      line!.alignment = content.alignment!;
    }

    if (content is LinkContent && content.footnotes.isNotEmpty) {
      // Layout the Footnotes on the page and try to work out how to display everything
    }

    for (LineElement el in content.elements) {
      if (content.isDropCaps) {
        currentPage.dropCapsYPosition = line!.yPos + el.height;
        currentPage.dropCapsXPosition = el.width;
      }

      if (!line!.willFitWidth(el) && el is! SpaceSeparator) {
        if (!currentPage.willFitHeight(line!)) {
          addPage();
          currentPage.dropCapsYPosition = el.height;
          line!.yPos = 0;
        }
        currentPage.addLine(line!);
        line = addLine(blockStyle: content.blockStyle, dropCapsIndent: currentPage.dropCapsXPosition,);
      }
      line!.addElement(el);
    }
  }

  Line addLine({required BlockStyle blockStyle, double? margin, double? dropCapsIndent}) {
    line?.completeLine();
    double lastHeight = line?.height ?? 0;
    double yPos = currentPage.currentBottomYPos + (margin ?? 0);
    Line newLine = Line(yPos: yPos, blockStyle: blockStyle);

    if (dropCapsIndent != null) {
      newLine.dropCapsIndent = dropCapsIndent;
    }
    currentPage.resetDropCaps(yPos+lastHeight);

    return newLine;
  }

  // So, the first <br> tag completes the current line if it isn't empty, or adds a line if it is empty.
  void addLineBreak(LineBreak content) {
    line!.completeParagraph();
    currentPage.addLine(line!);

    line = addLine(margin: line!.isEmpty ? line!.height : 0, blockStyle: content.blockStyle, dropCapsIndent: currentPage.dropCapsXPosition);
    line!.setTextIndent(content.leftIndent);
  }

  void addPage() {
    _pageListener?.addPage(currentPage);

    Page newPage = Page();
    newPage.dropCapsXPosition = currentPage.dropCapsXPosition;
    newPage.dropCapsYPosition = currentPage.dropCapsYPosition;


    currentPage = newPage;
  }

  void addParagraphBreak(ParagraphBreak content) {
    if (line != null) {
      line!.completeParagraph();
      currentPage.addLine(line!);
    }
    line = addLine(margin: content.margin, blockStyle: content.blockStyle, dropCapsIndent: currentPage.dropCapsXPosition);
    line!.setTextIndent(content.leftIndent);
  }
}