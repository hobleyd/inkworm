import 'package:flutter/material.dart';

import 'separator.dart';

class HyphenSeparator extends Separator {
  @override
  final TextStyle style;
  late final InlineSpan hyphen;

  @override
  get element => hyphen;

  HyphenSeparator({required this.style}) {
    hyphen = TextSpan(text: "-", style: style);

    getTextConstraints(hyphen);
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