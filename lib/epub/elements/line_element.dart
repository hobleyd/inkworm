import 'package:flutter/material.dart';

import '../content/html_content.dart';
import '../styles/element_style.dart';

abstract class LineElement {
  double height;
  double width;

  HtmlContent get element;

  VerticalAlignment get verticalAlignment => element.elementStyle.verticalAlignment;
  bool    get isDropCaps      => element.elementStyle.isDropCaps ?? false;
  double  get ascent          => 0;
  double  get marginLeft      => element.blockStyle.marginLeft;
  double  get marginRight     => element.blockStyle.marginRight;

  LineElement({required this.width, required this.height});

  void paint(Canvas c, double height, double xPos, double yPos);

  @override
  String toString() {
    return '($width/$height) ${element.elementStyle.textStyle.fontFamily} $element';
  }
}