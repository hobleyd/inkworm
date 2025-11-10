import 'package:flutter/material.dart';

import '../content/html_content.dart';
import '../content/text_content.dart';
import '../constants.dart';

abstract class LineElement {
  late double height;
  late double width;
  bool isDropCaps = false;

  // TODO
  // Link _link;

  HtmlContent get element;

  LineElement();

  void getConstraints() {
    TextPainter painter = TextPainter(text: (element as TextContent).span, textDirection: TextDirection.ltr,);
    painter.layout(maxWidth: PageConstants.canvasWidth - PageConstants.leftIndent - PageConstants.rightIndent);

    height = painter.height;
    width  = painter.width;
  }

  void paint(Canvas c, double height, double xPos, double yPos);

  @override
  String toString() {
    return '$element';
  }
}