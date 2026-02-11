import 'package:flutter/material.dart';

import '../content/html_content.dart';
import '../content/image_bytes_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';

Map<String, Object?> blockStyleToMap(BlockStyle style) {
  return {
    'leftMargin': style.leftMargin,
    'rightMargin': style.rightMargin,
    'topMargin': style.topMargin,
    'bottomMargin': style.bottomMargin,
    'leftIndent': style.leftIndent,
    'alignment': style.alignment?.index,
    'maxHeight': style.maxHeight,
    'maxWidth': style.maxWidth,
  };
}

Map<String, Object?> elementStyleToMap(ElementStyle style) {
  final decoration = style.textStyle.decoration;
  int? decorationBits;
  if (decoration != null) {
    int bits = 0;
    if (decoration.contains(TextDecoration.underline)) {
      bits |= 1;
    }
    if (decoration.contains(TextDecoration.lineThrough)) {
      bits |= 2;
    }
    if (decoration.contains(TextDecoration.overline)) {
      bits |= 4;
    }
    decorationBits = bits == 0 ? null : bits;
  }

  return {
    'fontSize': style.textStyle.fontSize,
    'fontFamily': style.textStyle.fontFamily,
    'fontWeight': style.textStyle.fontWeight?.index,
    'fontStyle': style.textStyle.fontStyle?.index,
    'decoration': decorationBits,
    'color': style.textStyle.color?.value,
    'isDropCaps': style.isDropCaps,
  };
}

Map<String, Object?> contentToMap(HtmlContent content) {
  return switch (content) {
    TextContent text => {
        'type': 'text',
        'text': text.text,
        'blockStyle': blockStyleToMap(text.blockStyle),
        'elementStyle': elementStyleToMap(text.elementStyle),
      },
    LinkContent link => {
        'type': 'link',
        'href': link.href,
        'src': contentToMap(link.src),
        'footnotes': link.footnotes.map(contentToMap).toList(),
        'blockStyle': blockStyleToMap(link.blockStyle),
        'elementStyle': elementStyleToMap(link.elementStyle),
      },
    LineBreak lineBreak => {
        'type': 'line_break',
        'blockStyle': blockStyleToMap(lineBreak.blockStyle),
        'elementStyle': elementStyleToMap(lineBreak.elementStyle),
      },
    ParagraphBreak paragraphBreak => {
        'type': 'paragraph_break',
        'blockStyle': blockStyleToMap(paragraphBreak.blockStyle),
        'elementStyle': elementStyleToMap(paragraphBreak.elementStyle),
      },
    ImageBytesContent imageBytes => {
        'type': 'image',
        'bytes': imageBytes.bytes,
        'blockStyle': blockStyleToMap(imageBytes.blockStyle),
        'elementStyle': elementStyleToMap(imageBytes.elementStyle),
      },
    _ => throw StateError('Unsupported content type: ${content.runtimeType}'),
  };
}
