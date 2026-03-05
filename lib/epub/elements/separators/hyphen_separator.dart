import 'package:flutter/material.dart';

import 'separator.dart';

class HyphenSeparator extends Separator {
  HyphenSeparator({required super.blockStyle, required super.elementStyle, required super.width, required super.height}) : super(separator: "-") {
    // I want to ensure Hyphens are a little more visible when displaying them.
    width = width * 1.5;
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    c.drawLine(
        Offset(xPos+1, yPos+(height/2)+1),
        Offset(xPos+width-1, yPos+(height/2)+1),
        Paint()..color = Colors.black..strokeWidth=1.4,
    );
  }

  @override
  String toString() {
    return "-";
  }
}