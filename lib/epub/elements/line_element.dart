import 'package:flutter/material.dart';

import '../content/html_content.dart';

abstract class LineElement {
  double height;
  double width;

  HtmlContent get element;

  bool    get alignToBaseline => element.elementStyle.alignToBaseline ?? false;
  bool    get isDropCaps      => element.elementStyle.isDropCaps ?? false;
  double  get marginRight     => element.blockStyle.marginRight;

  LineElement({required this.width, required this.height});

  void paint(Canvas c, double height, double xPos, double yPos);

  @override
  String toString() {
    return '($width/$height) ${element.elementStyle.textStyle.fontFamily} $element';
  }
}