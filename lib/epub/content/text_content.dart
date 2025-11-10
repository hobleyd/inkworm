import 'package:flutter/material.dart';

import 'html_content.dart';

class TextContent extends HtmlContent {
  final String text;

  TextSpan get span => TextSpan(text: text, style: elementStyle.textStyle);

  const TextContent({required super.blockStyle, required super.elementStyle, required this.text});
}
