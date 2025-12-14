import 'package:flutter/material.dart';

import '../content/html_content.dart';
import '../content/text_content.dart';
import 'line_element.dart';

class LinkElement extends LineElement {
  final LineElement src;
  final String href;

  @override
  get element => src.element;

  LinkElement({required this.src, required this.href}) {
    getConstraints();
  }

  @override
  void getConstraints() async {
    return src.getConstraints();
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    return src.paint(c, height, xPos, yPos);
    //c.drawLine(Offset(xPos, yPos+height+2), Offset(xPos + width, yPos+height+2), Paint()..color = Colors.black);
  }

  @override
  String toString() {
    return '$src [$href]';
  }
}