import 'package:flutter/material.dart';
import 'package:inkworm/epub/content/text_content.dart';

import 'separator.dart';

class HyphenSeparator extends Separator {
  HyphenSeparator({required super.style}) : super(separator: TextContent(blockStyle: style, span: TextSpan(text: "-", style: style.elementStyle.textStyle),)) {
    getConstraints();
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    c.drawLine(Offset(xPos, yPos+(height/2)+1), Offset(xPos+width, yPos+(height/2)+1), Paint()..color = Colors.black);
  }

  @override
  String toString() {
    return "-";
  }
}