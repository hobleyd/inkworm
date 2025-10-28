import 'package:flutter/material.dart';

import '../../content/text_content.dart';
import 'separator.dart';

class SpaceSeparator extends Separator {
  SpaceSeparator({required super.style}) : super(separator: TextContent(blockStyle: style, span: TextSpan(text: "-", style: style.elementStyle.textStyle),)) {
    getConstraints();
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    // No need to do anything for a Space character!
  }

  @override
  String toString() {
    return " ";
  }
}