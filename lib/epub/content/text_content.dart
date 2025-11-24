import 'package:flutter/material.dart';

import '../elements/line_element.dart';
import '../elements/separators/hyphen_separator.dart';
import '../elements/separators/non_breaking_space_separator.dart';
import '../elements/separators/space_separator.dart';
import '../elements/word_element.dart';
import 'html_content.dart';

class TextContent extends HtmlContent {
  final String text;

  TextSpan get span => TextSpan(text: text, style: elementStyle.textStyle);

  @override
  Iterable<LineElement> get elements {
    // Split the span into text and spaces or hyphens - such that we can modify the width of the latter two in order to support justification.
    final List<String> words = splitSpan(text);

    return words.map((word) {
      return switch (word) {
        '-' || '\u{2014}' => HyphenSeparator(blockStyle: blockStyle, elementStyle: elementStyle),
        ' '               => SpaceSeparator(blockStyle: blockStyle, elementStyle: elementStyle),
        '\u{00A0}'        => NonBreakingSpaceSeparator(blockStyle: blockStyle, elementStyle: elementStyle),
        _                 => WordElement(word: TextContent(blockStyle: blockStyle, text: word.trim(), elementStyle: elementStyle)),
      };
    });
  }

  const TextContent({required super.blockStyle, required super.elementStyle, required this.text});

  List<String> splitSpan(String span) {
    List<String> result = [];
    String current = "";

    for (int i = 0; i < span.length; i++) {
      String char = span[i];

      if (char == '-' || char == '\u{2014}' || char == ' ' || char == '\u{00A0}') {
        if (current.isNotEmpty) {
          result.add(current);
          current = "";
        }
        result.add(char);
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      result.add(current);
    }

    return result;
  }

  @override
  String toString() {
    return text;
  }
}
