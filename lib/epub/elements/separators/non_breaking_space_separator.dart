import 'package:flutter/material.dart';

import 'separator.dart';

class NonBreakingSpaceSeparator extends Separator {
  NonBreakingSpaceSeparator({required super.blockStyle, required super.elementStyle}) : super(separator: " ") {
    getConstraints();
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