import 'package:flutter/material.dart';

import '../content/text_content.dart';
import 'line_element.dart';

@immutable
class WordElement extends LineElement {
  final TextContent word;

  @override
  get element => word;

  @override
  get style => word.blockStyle;

  WordElement({required this.word}) {
    getConstraints();
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    final TextPainter textPainter = TextPainter(text: word.span, textDirection: TextDirection.ltr);
    textPainter.layout(maxWidth: width);
    textPainter.paint(c, Offset(xPos, yPos));
  }

  @override
  String toString() {
    return word.toString();
  }
}