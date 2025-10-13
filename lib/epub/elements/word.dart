import 'package:flutter/material.dart';

import 'line_element.dart';

@immutable
class Word extends LineElement {
  final InlineSpan word;

  @override
  get element => word;

  @override
  get style => word.style!;

  Word({required this.word}) {
    getTextConstraints(word);
  }

  @override
  String toString() {
    return word.toPlainText();
  }
}