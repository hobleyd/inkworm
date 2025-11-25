import '../constants.dart';
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
// is too close to the bottom to do this, mayne adjust the line heights to justify the height and move the footnote to the next page.
// This will require careful testing.

class EpubPage {
  List<Line> lines = [];
  List<Line> overflow = [];

  Line? get currentLine => getActiveLines().last;
  bool get isCurrentLineEmpty => getActiveLines().isNotEmpty && currentLine!.elements.isEmpty;

  double dropCapsXPosition = 0;
  double dropCapsYPosition = 0;

  EpubPage();

  void addLine({required bool paragraph, double? margin, required BlockStyle blockStyle, double? dropCapsIndent, bool? overflowRequired}) {
    // Close off the previous line to calculate justification etc.
    if (lines.isEmpty) {
      lines.add(Line(yPos: 0 + (margin ?? 0), blockStyle: blockStyle));
    } else {
      currentLine!.completeLine();

      // If we need to move to a new page, add these to the overflow list and let the calling process worry about creating a new page.
      Line line = Line(yPos: currentLine!.yPos + currentLine!.height + (margin ?? 0), blockStyle: blockStyle);

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
      getActiveLines().last.textIndent = blockStyle.leftIndent ?? PageConstants.leftIndent * 1.5;
    }
  }

  // Used to add overflow lines into a new page creating by the calling class.
  // TODO: think about what happens if a paragraph stretches over more than 1 overflow page. If it becomes an issue! (It will!)
  void addLines(List<Line> lines) {
    this.lines.addAll(lines);
  }

  // This will add a paragraph of text, line by line, to the current Page.
  List<Line> addElement(bool newParagraph, HtmlContent content, List<HtmlContent> footnotes) {
    if (lines.isEmpty || newParagraph) {
      addLine(paragraph: newParagraph, blockStyle: content.blockStyle);
    }

    for (LineElement el in content.elements) {
      // While this is in a loop a dropcaps entry will only have a single element anyway so not a major concern.
      if (content.elementStyle.isDropCaps ?? false) {
        dropCapsYPosition = currentLine!.yPos + el.height;
        dropCapsXPosition = el.width;
      }

      if (!currentLine!.willFitHeight(el)) {
        // This would have to be an image, or (theoretically) a suddenly changed font size.
        addLine(
          paragraph: newParagraph,
          blockStyle: content.blockStyle,
          dropCapsIndent: dropCapsXPosition,
          overflowRequired: true,
        );

        currentLine!.addElement(el);
      } else {
        if (currentLine!.willFitWidth(el)) {
          currentLine!.addElement(el);
        } else {
          if (dropCapsYPosition < currentLine!.bottomYPosition + currentLine!.height) {
            // Add the line height to the current bottomYPosition to get the next line position, prior to adding it.
            if (dropCapsXPosition > 0) {
              dropCapsXPosition = 0;
              dropCapsYPosition = 0;
            }
          }
          if (el is! SpaceSeparator) {
            // No need to add spaces to a new line. Also don't add the Line as we don't need it if we only have
            // a SpaceSeparator. This will create the line the next time through.
            addLine(
              paragraph: false,
              blockStyle: content.blockStyle,
              dropCapsIndent: dropCapsXPosition,
            );

            currentLine!.addElement(el);
          }
        }
      }
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