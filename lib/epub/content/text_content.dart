import 'package:flutter/material.dart';

import 'html_content.dart';

class TextContent extends HtmlContent {
  final TextSpan span;

  const TextContent({required super.blockStyle, required this.span});
}
