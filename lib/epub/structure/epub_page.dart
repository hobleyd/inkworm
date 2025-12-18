import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../content/html_content.dart';
import '../styles/block_style.dart';
import 'separators/space_separator.dart';
import 'line.dart';
import 'line_element.dart';

// Pseudo code:
// Ensure we have the current height of the page as well as the absolute height of the Canvas.
// measure the height of the TextSpan provided; if it fits on the page, add it.
// If it doesn't, split the Span and fit as much as possible on the page. then return the part of the span which does not fit on the Page
// With regards footnotes, if the Span has a footnote, check to see if the footnote size fits on the page with the span.
// If not, add the footnote and split the span until it all fits. If the footnote moves to a subsequent page, we need to get tricky.
// I am thinking we display one or two lines of the footnote on this page and move the rest to the next page. If the footnote reference
// is too close to the bottom to do this, maybe adjust the line heights to justify the height and move the footnote to the next page.
// This will require careful testing.

// Note that when dealing with Footnotes, some footnotes will also contain footnotes! Blame Terry Pratchett.

class EpubPage {
  List<Line> lines = [];
  List<Line> overflow = [];
  List<Line> footnotes = [];
  List<Line> footnotesOverflow = [];

  Line?  get currentLine           => getActiveLines().last;
  double get currentLineBottomYPos => currentLine!.yPos + currentLine!.height;
  bool   get isCurrentLineEmpty    => getActiveLines().isNotEmpty && currentLine!.elements.isEmpty;

  double dropCapsXPosition = 0;
  double dropCapsYPosition = 0;

  EpubPage();

  void addLine({required bool paragraph, required BlockStyle blockStyle, double? margin, double? dropCapsIndent, bool? overflowRequired}) {
    if (lines.isEmpty) {
      lines.add(Line(yPos: 0 + (margin ?? 0), blockStyle: blockStyle));
    } else {
      // Close off the previous line to calculate justification etc.
      currentLine!.completeLine();

      // If we need to move to a new page, add these to the overflow list and let the calling process worry about creating a new page.
      double yPos = currentLineBottomYPos + (margin ?? 0);
      Line line = Line(yPos: yPos, blockStyle: blockStyle);

      // Reset the dropcaps vars once the line is below the bottom of the dropcaps character.
      if (dropCapsYPosition < yPos + getActiveLines().last.height) {
        dropCapsXPosition = 0;
        dropCapsYPosition = 0;
      }

      if (dropCapsIndent != null) {
        line.dropCapsIndent = dropCapsIndent;
      }

      if (overflowRequired ?? false) {
        if (overflow.isEmpty) {
          line.yPos = 0;
        }
        overflow.add(line);
      } else {
        getActiveLines().add(line);
      }
    }

    if (paragraph) {
      PageSize size = GetIt.instance.get<PageSize>();
      getActiveLines().last.textIndent = blockStyle.leftIndent ?? size.leftIndent * 1.5;
    }
  }

  // Used to add overflow lines into a new page creating by the calling class.
  List<Line> addOverflow(List<Line> lines) {
    PageSize size = GetIt.instance.get<PageSize>();

    List<Line> overflow = [];
    for (Line line in lines) {
      if ((line.yPos + line.height) <= size.canvasHeight) {
        this.lines.add(line);
      } else {
        overflow.add(line);
      }
    }
    return overflow;
  }

  // This will add a paragraph of text, line by line, to the current Page.
  List<Line> addElement(HtmlContent content, List<HtmlContent> footnotes, { bool? paragraph }) {
    for (LineElement el in content.elements) {
      if (content.elementStyle.isDropCaps ?? false) {
        dropCapsYPosition = currentLine!.yPos + el.height;
        dropCapsXPosition = el.width;
      }

      if (!currentLine!.willFitHeight(el)) {
        // This would have to be an image, or (theoretically) a suddenly changed font size.
        // Don't set the DCI here as if we need it, it will be on a subsequent line.
        addLine(paragraph: paragraph ?? false, blockStyle: content.blockStyle, overflowRequired: true,);
        // reset the dropcaps y position for the new page.
        dropCapsYPosition = el.height;
      }
      else if (!currentLine!.willFitWidth(el) && el is! SpaceSeparator) {
        PageSize size = GetIt.instance.get<PageSize>();
        addLine(
            paragraph: false,
            blockStyle: content.blockStyle,
            dropCapsIndent: dropCapsXPosition,
            overflowRequired: (currentLineBottomYPos + el.height) > size.canvasHeight);
      }
      currentLine!.addElement(el);
    }

    return overflow;
  }

  void clear() {
    overflow.clear();
  }

  List<Line> getActiveLines() {
    return overflow.isNotEmpty ? overflow : lines;
  }


}