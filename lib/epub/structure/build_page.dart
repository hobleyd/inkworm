import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/elements/word_element.dart';

import '../content/html_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import '../elements/line_element.dart';
import '../elements/separators/space_separator.dart';
import '../styles/block_style.dart';
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

  set pageListener(PageListener? listener) => _pageListener = listener;

  void addContent(List<HtmlContent> contents) {
    BuildLine buildLine = GetIt.instance.get<BuildLine>();
    buildLine.lineListener = this;

    // Construct a line from the elements; once complete check whether it will fit on the current page, or will require a new
    // page to sit in. Send the completed page to any listeners.
    for (HtmlContent content in contents) {
      // A Paragraph break will complete the previous line, before adding a new line for the new paragraph.
      switch (content) {
        case ParagraphBreak pb: addParagraphBreak(pb);
        case      LineBreak lb: addLineBreak(lb);
        case    LinkContent lc: addFootnote(lc);
        default:                addElements(content);
      }
    }
    addPage();
  }

  // This will add text, element by element, to the current Line, creating a new Page when required. It will not necessarily
  // be a complete paragraph.
  void addElements(HtmlContent content,) {
    BuildLine buildLine = GetIt.instance.get<BuildLine>();
    buildLine.setAlignment(content.alignment);

    for (LineElement el in content.elements) {
      if (content.isDropCaps) {
        currentPage.dropCapsYPosition = currentPage.currentBottomYPos + el.height;
        currentPage.dropCapsXPosition = el.width;
      }

      buildLine.addElement(el);
    }
  }

  void addFootnote(LinkContent content,) {
    BuildLine buildLine = GetIt.instance.get<BuildLine>();
    buildLine.setAlignment(content.alignment);
    addElements(content.src);
  }

  @override
  void addLine(Line line) {
    if (!currentPage.willFitHeight(line)) {
      addPage();
    }
    line.yPos = currentPage.currentBottomYPos;
    currentPage.addLine(line);

    BuildLine buildLine = GetIt.instance.get<BuildLine>();
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
  void addLineBreak(LineBreak content) {
    BuildLine buildLine = GetIt.instance.get<BuildLine>();
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

  void addParagraphBreak(ParagraphBreak content) {
    BuildLine buildLine = GetIt.instance.get<BuildLine>();
    buildLine.completeParagraph();
    buildLine.textIndent = content.leftIndent ?? 0;

    currentPage.currentBottomYPos += content.margin;
  }
}