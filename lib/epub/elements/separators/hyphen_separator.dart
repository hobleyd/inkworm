import 'package:flutter/material.dart';

import 'separator.dart';

class HyphenSeparator extends Separator {
  HyphenSeparator({required super.blockStyle, required super.elementStyle}) : super(separator: "-") {
    getConstraints();
  }

  @override
  Future<bool> getConstraints() async {
    // I want to ensure Hyphens are a little more visible when displaying them.
    await super.getConstraints();
    width = width * 1.5;

    return true;
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