import 'package:flutter/material.dart';

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
  final double maxHeight;
  final double maxWidth;
  double _currentHeight = 0;

  List<TextSpan> spans = [];

  EpubPage({required this.maxHeight, required this.maxWidth});

  TextSpan? addText(TextSpan span, List<TextSpan> footnotes) {
    TextPainter painter = TextPainter(text: span, textScaler: TextScaler.linear(1), textDirection: TextDirection.ltr,);
    painter.layout(maxWidth: maxWidth);

    if (_currentHeight + painter.size.height <= maxHeight) {
      spans.add(span);
      _currentHeight += painter.size.height;
      return null;
    }

    return splitText(span, painter);
  }

  TextSpan splitText(TextSpan span, TextPainter painter, double computedHeight) {
    double heightRemaining = maxHeight - _currentHeight;

    double charWidth = 0.48 * 12; // TODO: this coefficient is dodgy
    double charHeight = painter.preferredLineHeight;
    int charInLine = maxWidth ~/ charWidth;
    int lines = heightRemaining ~/ charHeight;

    int splitStart = (charInLine * lines).toInt();
    spans.add(TextSpan(text: span.text!.substring(0, splitStart), style: span.style));

    return TextSpan(text: span.text!.substring(splitStart), style: span.style!);
  }
}