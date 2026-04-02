import 'package:flutter/material.dart';

import 'line_element.dart';

class LinkElement extends LineElement {
  final LineElement src;
  final String href;

  @override
  get element => src.element;

  LinkElement({required super.height, required super.width, required this.src, required this.href,});

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    return src.paint(c, height, xPos, yPos);
  }

  @override
  String toString() {
    return '$src [$href]';
  }
}