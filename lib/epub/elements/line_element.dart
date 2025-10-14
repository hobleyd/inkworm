import 'package:flutter/material.dart';
import 'package:inkworm/epub/constants.dart';

abstract class LineElement {
  late double height;
  late double width;
  bool isDropCaps = false;

  // TODO
  // Link _link;

  InlineSpan get element;
  TextStyle get style;

  LineElement();

  void getTextConstraints(InlineSpan span) {
    TextPainter painter = TextPainter(text: span, textDirection: TextDirection.ltr,);
    painter.layout(maxWidth: PageConstants.canvasWidth - PageConstants.leftIndent - PageConstants.rightIndent);

    height = painter.height;
    width  = painter.width;
  }

  void paint(Canvas c, double xPos, double yPos);

  @override
  String toString() {
    return '$element';
  }
}