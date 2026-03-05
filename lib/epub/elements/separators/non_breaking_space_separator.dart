import 'package:flutter/material.dart';

import 'separator.dart';

class NonBreakingSpaceSeparator extends Separator {
  NonBreakingSpaceSeparator({required super.blockStyle, required super.elementStyle, required super.width, required super.height}) : super(separator: " ");

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    // final TextPainter textPainter = TextPainter(text: TextSpan(text: " ", style: elementStyle.textStyle), textDirection: TextDirection.ltr,);
    // textPainter.layout(maxWidth: width);
    // textPainter.paint(c, Offset(xPos, yPos));
    //
    // textPainter.dispose();
  }

  @override
  String toString() {
    return " ";
  }
}