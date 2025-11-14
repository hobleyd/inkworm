import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:measure_text/measure_text.dart';

import '../content/html_content.dart';
import '../content/text_content.dart';
import '../constants.dart';

abstract class LineElement {
  late double height;
  late double width;

  // TODO
  // Link _link;

  HtmlContent get element;

  LineElement();

  void getConstraints() async {
    TextPainter painter = TextPainter(
      text: (element as TextContent).span,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: PageConstants.canvasWidth - PageConstants.leftIndent - PageConstants.rightIndent);

    width = painter.width;
    height = painter.height;

    // TODO: this is completely fucked. Flutter literally doesn't return the correct width and everything else I have
    // tried: getBoxesForSelection, computeLineMetrics, getOffsetForCaret and even Picture Recorder don't work.
    // So, I have special cased this for now and will have to investigate further.
    if (element.elementStyle.textStyle.fontFamily == 'Great Vibes') {
      width = width * 1.5;
    }

    painter.dispose();
  }

  void paint(Canvas c, double height, double xPos, double yPos);

  @override
  String toString() {
    return '$element';
  }
}