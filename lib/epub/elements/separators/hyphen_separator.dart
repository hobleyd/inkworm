import 'package:flutter/material.dart';

import 'separator.dart';

class HyphenSeparator extends Separator {
  HyphenSeparator({required super.blockStyle, required super.elementStyle, required super.width, required super.height}) : super(separator: "-") {
    // I want to ensure Hyphens are a little more visible when displaying them.
    width = width * 1.5;
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    final double y = (yPos + height / 2 + 1).roundToDouble();
    c.drawLine(
        Offset(xPos+1, y),
        Offset(xPos+width-1, y),
        Paint()..color = Colors.black..strokeWidth=1.0..isAntiAlias=false,
    );
  }

  @override
  String toString() {
    return "-";
  }
}