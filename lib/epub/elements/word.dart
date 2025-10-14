import 'package:flutter/material.dart';

import 'line_element.dart';

@immutable
class Word extends LineElement {
  final InlineSpan word;

  @override
  get element => word;

  @override
  get style => word.style!;

  Word({required this.word}) {
    getTextConstraints(word);
  }

  @override
  void paint(Canvas c, double xPos, double yPos) {
    final TextPainter textPainter = TextPainter(text: word, textDirection: TextDirection.ltr);
    textPainter.layout(maxWidth: width);
    textPainter.paint(c, Offset(xPos, yPos));
  }

  @override
  String toString() {
    return '${word.toPlainText()} ($width)';
  }
}