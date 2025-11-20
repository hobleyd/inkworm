import 'package:flutter/material.dart';

import '../content/text_content.dart';
import 'line_element.dart';

class LinkElement extends LineElement {
  final TextContent text;
  final String href;

  @override
  get element => text;

  LinkElement({required this.text, required this.href}) {
    getConstraints();
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    final TextPainter textPainter = TextPainter(text: text.span, textDirection: TextDirection.ltr,);
    textPainter.layout(maxWidth: width);
    textPainter.paint(c, Offset(xPos, yPos));
    //c.drawLine(Offset(xPos, yPos+height+2), Offset(xPos + width, yPos+height+2), Paint()..color = Colors.black);

    textPainter.dispose();
  }

  @override
  String toString() {
    return '$text [$href]';
  }
}