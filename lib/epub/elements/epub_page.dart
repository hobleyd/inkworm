import 'package:flutter/material.dart';
import 'package:inkworm/epub/elements/separators/non_breaking_space_separator.dart';


import '../constants.dart';
import 'line_element.dart';
import 'separators/hyphen_separator.dart';
import 'separators/space_separator.dart';
import 'line.dart';
import 'word.dart';

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

  EpubPage();

  void addLine(bool paragraph) {
    // Close off the previous line to calculate justification etc.
    if (lines.isEmpty) {
      lines.add(Line(yPos: 0));
    } else {
      getActiveLines().last.finish();

      // If we need to move to a new page, add these to the overflow list and let the calling process worry about creating a new page.
      Line line = Line(yPos: getActiveLines().last.yPos + getActiveLines().last.height);
      if ((line.yPos + getActiveLines().last.height) > PageConstants.canvasHeight) {
        if (overflow.isEmpty) {
          line.yPos = 0;
        }
        overflow.add(line);
      } else {
        getActiveLines().add(line);
      }
    }

    // TODO: drive this off the style
    if (paragraph) {
      getActiveLines().last.textIndent = PageConstants.leftIndent * 1.5;
    }
  }

  // Used to add overflow lines into a new page creating by the calling class.
  // TODO: think about what happens if a paragraph stretches over more than 1 overflow page. If it becomes an issue! (It will!)
  void addLines(List<Line> lines) {
    this.lines.addAll(lines);
  }

  // This will add a paragraph of text, line by line, to the current Page.
  List<Line> addText(TextSpan span, List<TextSpan> footnotes) {
      addLine(true);

    // Split the span into text and spaces or hyphens - such that we can modify the width of the latter two in order to support justification.
    final List<String> words = splitSpan(span.text!);
    for (String word in words) {
      LineElement el = switch (word) {
        '-' || '\u{2014}'  => HyphenSeparator(style: span.style!),
        ' '                => SpaceSeparator(style: span.style!),
        '\u{00A0}'         => NonBreakingSpaceSeparator(style: span.style!),
         _                 => Word(word: TextSpan(text: word.trim(), style: span.style)),
      };

      if (getActiveLines().last.willFit(el)) {
        getActiveLines().last.addElement(el);
      } else {
        addLine(false);
        if (el is! SpaceSeparator) {
          // No need to add spaces to a new line.
          getActiveLines().last.addElement(el);
        }
      }
    }

    getActiveLines().last.alignment = LineAlignment.left;

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