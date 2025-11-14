import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../content/html_content.dart';
import '../content/image_content.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import 'separators/hyphen_separator.dart';
import 'separators/non_breaking_space_separator.dart';
import 'separators/space_separator.dart';
import 'image_element.dart';
import 'line.dart';
import 'line_element.dart';
import 'word_element.dart';

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

  double dropCapsXPosition = 0;
  double dropCapsYPosition = 0;

  EpubPage();

  void addImage(ImageContent image, bool inline) {
    if (!inline) {
      if (lines.isNotEmpty) {
        getActiveLines().last.finish();
      }
      addLine(paragraph: true, blockStyle: image.blockStyle);
    }

    ImageElement el = ImageElement(image: image);

    if (image.elementStyle.isDropCaps ?? false) {
      dropCapsYPosition = getActiveLines().last.yPos + el.height;
      dropCapsXPosition = el.width;
    }

    if (getActiveLines().last.willFit(el)) {
      getActiveLines().last.addElement(el);
    } else {
      // TODO: this is ugly and if the dropcaps is on the very first line, not sure that this will work.
      // But generally Chapter Headers are a thing and so shouldn't be a real issue.
      if (dropCapsYPosition > 0) {
        if (dropCapsYPosition > getActiveLines().last.yPos) {
          if (dropCapsXPosition > 0) {
            dropCapsXPosition = 0;
            dropCapsYPosition = 0;
          }
        }
      }

      addLine(
          paragraph: false,
          blockStyle: image.blockStyle,
          dropCapsIndent: dropCapsXPosition,
      );
      getActiveLines().last.addElement(el);
    }

    if (!inline) {
      getActiveLines().last.finish();
    }
  }

  void addLine({required bool paragraph, required BlockStyle blockStyle, double? dropCapsIndent}) {
    // Close off the previous line to calculate justification etc.
    if (lines.isEmpty) {
      lines.add(Line(yPos: 0, blockStyle: blockStyle));
    } else {
      // Don't justify the last line in a paragraph.
      if (paragraph && getActiveLines().last.alignment == LineAlignment.justify) {
        getActiveLines().last.alignment = LineAlignment.left;
      }

      getActiveLines().last.finish();

      // If we need to move to a new page, add these to the overflow list and let the calling process worry about creating a new page.
      Line line = Line(yPos: getActiveLines().last.yPos + getActiveLines().last.height, blockStyle: blockStyle);

      if (dropCapsIndent != null) {
        line.dropCapsIndent = dropCapsIndent;
      }

      if ((line.yPos + getActiveLines().last.height) > PageConstants.canvasHeight) {
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
  List<Line> addText(TextContent content, List<HtmlContent> footnotes) {
    if (lines.isEmpty) {
      addLine(paragraph: true, blockStyle: content.blockStyle);
    }

    // Split the span into text and spaces or hyphens - such that we can modify the width of the latter two in order to support justification.
    final List<String> words = splitSpan(content.span.text!);
    for (String word in words) {
      LineElement el = switch (word) {
        '-' || '\u{2014}'  => HyphenSeparator(blockStyle: content.blockStyle, elementStyle: content.elementStyle),
        ' '                => SpaceSeparator(blockStyle: content.blockStyle, elementStyle: content.elementStyle),
        '\u{00A0}'         => NonBreakingSpaceSeparator(blockStyle: content.blockStyle, elementStyle: content.elementStyle),
         _                 => WordElement(word: TextContent(blockStyle: content.blockStyle, text: word.trim(), elementStyle: content.elementStyle)),
      };

      // While this in a loop a dropcaps entry will only have a single element anyway so not a major concern.
      if (content.elementStyle.isDropCaps ?? false) {
        dropCapsYPosition = getActiveLines().last.yPos + el.height;
        dropCapsXPosition = el.width;
      }

      if (getActiveLines().last.willFit(el)) {
        getActiveLines().last.addElement(el);
      } else {
        if (dropCapsYPosition < getActiveLines().last.bottomYPosition + getActiveLines().last.height) {
          // Add the line height to the current bottomYPosition to get the next line position, prior to adding it.
          if (dropCapsXPosition > 0) {
            dropCapsXPosition = 0;
            dropCapsYPosition = 0;
          }
        }
        addLine(
            paragraph: false,
            blockStyle: content.blockStyle,
            dropCapsIndent: dropCapsXPosition,
        );

        if (el is! SpaceSeparator) {
          // No need to add spaces to a new line.
          getActiveLines().last.addElement(el);
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

  List<String> splitSpan(String span) {
    List<String> result = [];
    String current = "";

    for (int i = 0; i < span.length; i++) {
      String char = span[i];

      if (char == '-' || char == '\u{2014}' || char == ' ' || char == '\u{00A0}') {
        if (current.isNotEmpty) {
          result.add(current);
          current = "";
        }
        result.add(char);
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      result.add(current);
    }

    return result;
  }
}