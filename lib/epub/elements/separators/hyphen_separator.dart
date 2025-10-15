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
  void paint(Canvas c, double xPos, double yPos) {
    // TODO: treat a hyphen as a variable width element when considering justification.
    final TextPainter textPainter = TextPainter(text: hyphen, textDirection: TextDirection.ltr);
    textPainter.layout(maxWidth: width);
    textPainter.paint(c, Offset(xPos, yPos));
  }

  @override
  String toString() {
    return "-";
  }
}