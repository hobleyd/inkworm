import 'package:flutter/material.dart';

import 'separator.dart';

class NonBreakingSpaceSeparator extends Separator {
  @override
  final TextStyle style;
  late final InlineSpan space;

  @override
  get element => space;

  NonBreakingSpaceSeparator({required this.style}) {
    space = TextSpan(text: " ", style: style);

    getTextConstraints(space);
  }

  @override
  void paint(Canvas c, double xPos, double yPos) {
    // No need to do anything for a Space character!
  }

  @override
  String toString() {
    return " ";
  }
}