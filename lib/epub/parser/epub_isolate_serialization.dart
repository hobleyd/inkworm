import 'package:flutter/material.dart';

import '../content/html_content.dart';
import '../content/image_bytes_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'epub_isolate_dto.dart';

ContentDto contentToDto(HtmlContent content) {
  return switch (content) {
    TextContent text => TextContentDto(
        text: text.text,
        blockStyle: _blockStyleToDto(text.blockStyle),
        elementStyle: _elementStyleToDto(text.elementStyle),
      ),
    LinkContent link => LinkContentDto(
        href: link.href,
        src: contentToDto(link.src),
        footnotes: link.footnotes.map(contentToDto).toList(),
        blockStyle: _blockStyleToDto(link.blockStyle),
        elementStyle: _elementStyleToDto(link.elementStyle),
      ),
    LineBreak lineBreak => LineBreakDto(
        blockStyle: _blockStyleToDto(lineBreak.blockStyle),
        elementStyle: _elementStyleToDto(lineBreak.elementStyle),
      ),
    ParagraphBreak paragraphBreak => ParagraphBreakDto(
        blockStyle: _blockStyleToDto(paragraphBreak.blockStyle),
        elementStyle: _elementStyleToDto(paragraphBreak.elementStyle),
      ),
    ImageBytesContent imageBytes => ImageBytesDto(
        bytes: imageBytes.bytes,
        blockStyle: _blockStyleToDto(imageBytes.blockStyle),
        elementStyle: _elementStyleToDto(imageBytes.elementStyle),
      ),
    _ => throw StateError('Unsupported content type: ${content.runtimeType}'),
  };
}

BlockStyleDto _blockStyleToDto(BlockStyle style) {
  return BlockStyleDto(
    leftMargin: style.leftMargin,
    rightMargin: style.rightMargin,
    topMargin: style.topMargin,
    bottomMargin: style.bottomMargin,
    leftIndent: style.leftIndent,
    alignment: style.alignment?.index,
    maxHeight: style.maxHeight,
    maxWidth: style.maxWidth,
  );
}

ElementStyleDto _elementStyleToDto(ElementStyle style) {
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

  return ElementStyleDto(
    fontSize: style.textStyle.fontSize,
    fontFamily: style.textStyle.fontFamily,
    fontWeight: style.textStyle.fontWeight?.index,
    fontStyle: style.textStyle.fontStyle?.index,
    decoration: decorationBits,
    color: style.textStyle.color?.value,
    isDropCaps: style.isDropCaps,
  );
}
