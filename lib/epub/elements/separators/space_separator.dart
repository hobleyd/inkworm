import 'package:flutter/material.dart';

import 'separator.dart';

class SpaceSeparator extends Separator {
  @override
  final TextStyle style;
  late final InlineSpan space;

  @override
  get element => space;

  SpaceSeparator({required this.style}) {
    space = TextSpan(text: " ", style: style);

    getTextConstraints(space);
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    // No need to do anything for a Space character!
  }

  @override
  String toString() {
    return " ";
  }
}