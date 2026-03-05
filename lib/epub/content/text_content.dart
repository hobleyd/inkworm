import 'package:flutter/material.dart';

import '../elements/line_element.dart';
import '../elements/separators/hyphen_separator.dart';
import '../elements/separators/non_breaking_space_separator.dart';
import '../elements/separators/space_separator.dart';
import '../elements/word_element.dart';
import 'html_content.dart';

class TextContent extends HtmlContent {
  final String text;

  @override
  final List<LineElement> elements = [];

  TextSpan get span => TextSpan(text: text, style: elementStyle.textStyle);

  TextContent({required super.blockStyle, required super.elementStyle, required super.height, required super.width, required this.text}) {
    elements.add(switch (text) {
      '-' || '\u{2014}' => HyphenSeparator(blockStyle: blockStyle, elementStyle: elementStyle, height: height, width: width),
      ' '               => SpaceSeparator(blockStyle: blockStyle, elementStyle: elementStyle, height: height, width: width),
      '\u{00A0}'        => NonBreakingSpaceSeparator(blockStyle: blockStyle, elementStyle: elementStyle, height: height, width: width),
      _                 => WordElement(word: this, height: height, width: width)
    });
  }

  @override
  String toString() {
    return text;
  }
}
