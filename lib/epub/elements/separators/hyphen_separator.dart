import 'package:flutter/material.dart';

import 'separator.dart';

class HyphenSeparator extends Separator {
  HyphenSeparator({required super.blockStyle, required super.elementStyle, required super.width, required super.height, super.separatorAscent}) : super(separator: "-");

  @override
  void paint(Canvas c, double lineHeight, double xPos, double yPos) {
    // Centre on this run's own measured height, not the line's overall height - a line
    // sharing space with a drop cap (or any taller neighbour) has a much taller lineHeight
    // than the text this hyphen sits between, which would otherwise pull it up out of place.
    final double y = (yPos + height / 2).roundToDouble();
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