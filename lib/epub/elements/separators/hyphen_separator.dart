import 'package:flutter/material.dart';

import 'separator.dart';

class HyphenSeparator extends Separator {
  HyphenSeparator({required super.blockStyle, required super.elementStyle}) : super(separator: "-") {
    getConstraints();
  }

  @override
  void getConstraints() {
    // I want to ensure Hyphens are a little more visible when displaying them.
    super.getConstraints();
    width = width * 1.5;
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    c.drawLine(Offset(xPos+1, yPos+(height/2)+1), Offset(xPos+width-1, yPos+(height/2)+1), Paint()..color = Colors.black);
  }

  @override
  String toString() {
    return "-";
  }
}