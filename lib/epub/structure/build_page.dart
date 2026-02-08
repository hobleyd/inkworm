import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../content/html_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import '../elements/line_element.dart';
import 'build_line.dart';
import 'line.dart';
import 'line_listener.dart';
import 'page.dart';
import 'page_listener.dart';

@LazySingleton()
class BuildPage implements LineListener {
  PageListener? _pageListener;
  Page currentPage = Page();
  Line? line;

  List<Line> get lines => currentPage.lines;

  set pageListener(PageListener? listener) => _pageListener = listener;

  void addContent(List<HtmlContent> contents, {BuildLine? buildLine}) {
    if (buildLine == null) {
      buildLine = GetIt.instance.get<BuildLine>();
      buildLine.lineListener = this;
    }

    addContents(contents, buildLine);
    addPage();
  }

  void addContents(List<HtmlContent> contents, BuildLine buildLine) {
    // Construct a line from the elements; once complete check whether it will fit on the current page, or will require a new
    // page to sit in. Send the completed page to any listeners.
    for (HtmlContent content in contents) {
      // A Paragraph break will complete the previous line, before adding a new line for the new paragraph.
      switch (content) {
        case ParagraphBreak pb: addParagraphBreak(pb, buildLine);
        case      LineBreak lb: addLineBreak(lb, buildLine);
        case    LinkContent lc: addLinkContent(lc, buildLine);
        default:                addElements(content, buildLine);
      }
    }
  }

  // This will add text, element by element, to the current Line, creating a new Page when required. It will not necessarily
  // be a complete paragraph.
  void addElements(HtmlContent content, BuildLine buildLine) {
    buildLine.setAlignment(content.alignment);

    for (LineElement el in content.elements) {
      if (content.isDropCaps) {
        currentPage.dropCapsYPosition = currentPage.currentBottomYPos + el.height;
        currentPage.dropCapsXPosition = el.width;
      }

      buildLine.addElement(el);
    }
  }

  void addLinkContent(LinkContent content, BuildLine buildLine) {
    // There are two types of link content - footnotes, and links to other section of the text (typically the contents page
    // from what I have seen). The latter can be dealt with by addElements, not this function which is more designed for
    // footnotes.
    if (content.footnotes.isEmpty) {
      return addElements(content.src, buildLine);
    }
    buildLine.setAlignment(content.alignment);
    addElements(content.src, buildLine);

    // Create a temp space to build the footnotes. While I use GetIt to provide a singleton generally for page & line builds,
    // footnotes require a separate space to build. Hence the direct instantiation. This is the only place I break the rules.
    // Honest.
    BuildPage footnotesPage = BuildPage();
    BuildLine footnotesLine = BuildLine();
    footnotesLine.lineListener = footnotesPage;

    footnotesPage.addContents(content.footnotes, footnotesLine);
    for (Line line in footnotesPage.lines) {
      currentPage.addFootnote(line);
    }
  }

  @override
  void addLine(Line line, BuildLine buildLine) {
    if (!currentPage.willFitHeight(line)) {
      addPage();
    }
    line.yPos = currentPage.currentBottomYPos;
    currentPage.addLine(line);

    buildLine.addLine();
    buildLine.setAlignment(line.alignment);

    if (currentPage.currentBottomYPos + line.maxHeight < currentPage.dropCapsYPosition) {
      buildLine.dropCapsIndent = currentPage.dropCapsXPosition;
    } else {
      currentPage.dropCapsXPosition = 0;
      currentPage.dropCapsYPosition = 0;
    }
  }

  // So, the first <br> tag completes the current line if it isn't empty, or adds a line if it is empty.
  void addLineBreak(LineBreak content, BuildLine buildLine) {
    buildLine.completeParagraph();

    currentPage.currentBottomYPos += buildLine.isNotEmpty ? buildLine.maxHeight : 0;
  }

  void addPage() {
    _pageListener?.addPage(currentPage);

    Page newPage = Page();
    newPage.dropCapsXPosition = currentPage.dropCapsXPosition;
    newPage.dropCapsYPosition = currentPage.dropCapsYPosition;

    currentPage = newPage;
    line = null;
  }

  void addParagraphBreak(ParagraphBreak content, BuildLine buildLine) {
    buildLine.completeParagraph();
    buildLine.textIndent = content.leftIndent ?? 0;

    currentPage.currentBottomYPos += content.margin;
  }
}