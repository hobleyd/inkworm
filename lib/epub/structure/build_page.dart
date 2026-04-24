import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../../models/page_size.dart';
import '../content/html_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import '../content/table/table_cell.dart';
import '../content/table/table_content.dart';
import '../content/table/table_row.dart';
import '../elements/line_element.dart';
import '../interfaces/line_listener.dart';
import '../interfaces/page_listener.dart';
import '../styles/table_style.dart';
import 'build_line.dart';
import 'line.dart';
import 'page.dart';

@LazySingleton()
class BuildPage implements LineListener {
  static const footnoteMargin = 3;

  PageListener? _pageListener;
  Page currentPage = Page();

  List<Line> get footnotes => currentPage.footnotes;

  List<Line> get lines => currentPage.lines;

  double get totalHeight => lines.totalHeight + footnotes.totalHeight;

  set pageListener(PageListener? listener) => _pageListener = listener;

  void addContent(List<HtmlContent> contents, {BuildLine? buildLine}) {
    if (buildLine == null) {
      buildLine = GetIt.instance.get<BuildLine>();
      buildLine.lineListener = this;
    }

    if (currentPage.pageHeight == 0) {
      PageSize size = GetIt.instance.get<PageSize>();
      currentPage.pageHeight = size.canvasHeight;
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
        case ParagraphBreak pb:
          addParagraphBreak(pb, buildLine);
        case LineBreak lb:
          addLineBreak(lb, buildLine);
        case LinkContent lc:
          addLinkContent(lc, buildLine);
        case TableContent tc:
          addTableContent(tc, buildLine);
        default:
          addElements(content, buildLine);
      }
    }
  }

  // This will add text, element by element, to the current Line, creating a new Page when required. It will not necessarily
  // be a complete paragraph.
  void addElements(HtmlContent content, BuildLine buildLine) {
    buildLine.setAlignment(content.alignment);

    for (LineElement el in content.elements) {
      if (content.isDropCaps && buildLine.isEmpty) {
        currentPage.dropCapsYPosition = currentPage.currentBottomYPos + el.height;
        currentPage.dropCapsXPosition = el.width + 3;
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

    // Create a temp space to build the footnotes. While I use GetIt to provide a singleton generally for page & line builds,
    // footnotes require a separate space to build. Hence the direct instantiation.
    BuildPage footnotesPage = BuildPage();
    BuildLine footnotesLine = BuildLine();
    footnotesLine.lineListener = footnotesPage;
    footnotesPage.addContents(content.footnotes, footnotesLine);

    // At this point, we have the footnote(s) and the current Line and we need to check they both fit on the page.
    if (currentPage.currentBottomYPos + buildLine.maxHeight + footnotesPage.totalHeight + footnoteMargin > currentPage.pageHeight) {
      addPage();
    }

    buildLine.setAlignment(content.alignment);
    addElements(content.src, buildLine);

    for (Line line in footnotesPage.lines) {
      currentPage.addFootnote(line);
    }

    // If the footnotes have footnotes, then the footNotesPage will also contain footnotes!
    // And if you have never read a Terry Pratchett book, go out and buy one immediately.
    for (Line line in footnotesPage.footnotes) {
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

    if (currentPage.currentBottomYPos + line.lineHeight < currentPage.dropCapsYPosition) {
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

    PageSize size = GetIt.instance.get<PageSize>();
    final double remainingDropCapsHeight = currentPage.dropCapsYPosition > currentPage.currentBottomYPos
        ? currentPage.dropCapsYPosition - currentPage.currentBottomYPos
        : 0;

    Page newPage = Page();
    newPage.dropCapsXPosition = currentPage.dropCapsXPosition;
    newPage.dropCapsYPosition = remainingDropCapsHeight;
    newPage.pageHeight = size.canvasHeight;

    currentPage = newPage;
  }

  void addParagraphBreak(ParagraphBreak content, BuildLine buildLine) {
    buildLine.completeParagraph();
    buildLine.textIndent = content.leftIndent ?? 0;

    currentPage.currentBottomYPos += content.margin;
  }

  // This is going to be complicated; we need to build out lines that relate to a table column in each row, work out the maximum
  // height and align the row according to CSS requirements. In effect we'll have different height lines of text and/or images
  // to be positioned on the page.
  void addTableContent(TableContent content, BuildLine buildLine) {
    final PageSize size = GetIt.instance.get<PageSize>();

    if (buildLine.isNotEmpty) {
      buildLine.completeLine();
    }

    // Because we don't know how big the Table Cells are at this point, we need to build each Table Row on a temp page
    // and then transfer them over to the currentPage once we have the heights calculated.
    // (This is why we don't have Table Elements as we do for the other types of HtmlContent - this is a multi-component
    // activity as the cells in the row relate to each other and so we have to build it out at once; there is no painting for a table
    // element to do.)
    for (final row in content.rows) {
      Map<int, List<Line>> rowLines = {};

      double leftYPos = size.leftIndent;
      for (final MapEntry(:key, :value) in row.entries) {
        // Ensure the lines have the correct width for the column.
        final double lineWidth = leftYPos + value.paddingLeft + value.width;
        var (tablePage, tableLine) = _getTemporaryBuildSpace(lineWidth);
        tablePage.addContents(value.contents, tableLine);
        rowLines[key] = tablePage.lines;
        for (final line in rowLines[key]!) {
          line.leftIndent = leftYPos + value.paddingLeft;
        }
        leftYPos += value.width;
      }

      // Now we have a full table row built, we can align the columns according to the TableStyle.
      double maxColumnHeight = _maxRowHeight(row, rowLines);
      Map<int, double> yPosAdjust = {};
      for (final MapEntry(:key, :value) in row.entries) {
        if (value.verticalAlignment != TableCellAlignment.top) {
          // Can only be middle or bottom here.
          final double columnHeight = _columnHeight(value, rowLines[key] ?? const <Line>[]);
          yPosAdjust[key] = value.verticalAlignment == TableCellAlignment.middle ? (maxColumnHeight - columnHeight) / 2 : maxColumnHeight - columnHeight;
        }
      }

      // Now the heights are known and aligned, we can add the lines to the current page!
      double yPosOnPage = currentPage.currentBottomYPos;

      // Ensure the row will fit on the current page
      if (yPosOnPage + maxColumnHeight >= size.canvasHeight) {
        addPage();
        yPosOnPage = 0;
      }

      for (final MapEntry(:key, :value) in rowLines.entries) {
        currentPage.currentBottomYPos = yPosOnPage + (yPosAdjust[key] ?? 0); // Reset this as each column needs to start from the same position on the page.
        for (int i = 0; i < value.length; i++) {
          buildLine.currentLine = value[i];
          if (i == value.length-1) {
            buildLine.completeParagraph();
          } else {
            buildLine.completeLine();
          }
        }
      }
    }
  }

  double _columnHeight(TableCell cell, List<Line> lines) {
    return cell.paddingTop +
        lines.fold(0.0, (sum, line) => sum + line.maxLineHeight) +
        cell.paddingBottom;
  }

  double _maxRowHeight(TableRow row, Map<int, List<Line>> rowLines) {
    return row.entries
        .map((entry) => _columnHeight(entry.value, rowLines[entry.key] ?? const <Line>[]))
        .fold(0.0, (max, sum) => sum > max ? sum : max);
  }

  (BuildPage, BuildLine) _getTemporaryBuildSpace(double width) {
    BuildPage page = BuildPage();
    page.currentPage.pageHeight = 10000; // Don't need to paginate this as it is temporary.

    BuildLine line = BuildLine(availableWidth: width+1, rightIndent: 0);
    line.lineListener = page;

    return (page, line);
  }
}
