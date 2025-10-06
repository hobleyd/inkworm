import 'package:flutter/material.dart';

import 'epub.dart';
import 'paragraph.dart';

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
  double _currentHeight = 0;

  List<Paragraph> spans = [];

  EpubPage();

  TextSpan? addText(TextSpan span, List<TextSpan> footnotes) {
    TextPainter painter = TextPainter(text: span, maxLines: null, textScaler: TextScaler.linear(1), textDirection: TextDirection.ltr,);
    painter.layout(maxWidth: Epub.instance.canvasWidth - Epub.instance.leftIndent - Epub.instance.rightIndent);

    double computedHeight = painter.size.height;

    if (_currentHeight + computedHeight < Epub.instance.canvasHeight) {
      spans.add(Paragraph(span: span, x: Epub.instance.leftIndent, y: _currentHeight));
      _currentHeight += computedHeight - (painter.preferredLineHeight/2);
      return null;
    }

    return splitText(span, painter);
  }

  void clear() {
    spans.clear();
  }

  List<String> splitAtLeftSpace(String text, int index) {
    if (index <= 0) {
      return ['', text];
    }

    if (index >= text.length) {
      return [text, ''];
    }

    int spaceIndex = text.lastIndexOf(' ', index - 1);

    // If no space found to the left, split at the beginning
    if (spaceIndex == -1) {
      return ['', text];
    }

    // Split at the space
    String leftChunk = text.substring(0, spaceIndex);
    String rightChunk = text.substring(spaceIndex + 1);

    return [leftChunk, rightChunk];
  }

  TextSpan splitText(TextSpan span, TextPainter painter) {
    double heightRemaining = Epub.instance.canvasHeight - _currentHeight;

    debugPrint('Splitting text:\n${span.text}\nremaining height: $heightRemaining, height: ${painter.height}');
    double charWidth = 0.48 * 12; // TODO: this coefficient is dodgy
    double charHeight = painter.preferredLineHeight;
    int charInLine = Epub.instance.canvasWidth ~/ charWidth;
    int lines = heightRemaining ~/ charHeight;

    int splitStart = (charInLine * (lines)).toInt();
    List<String> splitList = splitAtLeftSpace(span.text!.trim(), splitStart);

    debugPrint('chars: $charInLine, lines: $lines\nX${splitList[0]}X\nX${splitList[1]}X');
    spans.add(Paragraph(span: TextSpan(text: splitList[0], style: span.style,), x: 0, y: _currentHeight));

    return TextSpan(text: splitList[1], style: span.style!);
  }
}