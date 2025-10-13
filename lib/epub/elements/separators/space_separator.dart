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
  String toString() {
    return " ";
  }
}