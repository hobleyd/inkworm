import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../content/html_content.dart';
import '../content/image_content.dart';
import '../content/line_break.dart';
import '../content/link_content.dart';
import '../content/paragraph_break.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'epub_isolate_dto.dart';

Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}

TextDecoration? _decorationFromBits(int? bits) {
  if (bits == null || bits == 0) {
    return null;
  }

  final values = <TextDecoration>[];
  if (bits & 1 != 0) {
    values.add(TextDecoration.underline);
  }
  if (bits & 2 != 0) {
    values.add(TextDecoration.lineThrough);
  }
  if (bits & 4 != 0) {
    values.add(TextDecoration.overline);
  }
  return TextDecoration.combine(values);
}

BlockStyle _blockStyleFromDto(BlockStyleDto dto, ElementStyle elementStyle) {
  final style = BlockStyle(elementStyle: elementStyle);
  style.leftMargin = dto.leftMargin;
  style.rightMargin = dto.rightMargin;
  style.topMargin = dto.topMargin;
  style.bottomMargin = dto.bottomMargin;
  style.leftIndent = dto.leftIndent;
  final alignmentIndex = dto.alignment;
  if (alignmentIndex != null) {
    style.alignment = LineAlignment.values[alignmentIndex];
  }
  style.maxHeight = dto.maxHeight;
  style.maxWidth = dto.maxWidth;
  return style;
}

ElementStyle _elementStyleFromDto(ElementStyleDto dto) {
  final style = ElementStyle();
  final fontWeightIndex = dto.fontWeight;
  final fontStyleIndex = dto.fontStyle;
  final colorValue = dto.color;
  style.textStyle = TextStyle(
    fontSize: dto.fontSize,
    fontFamily: dto.fontFamily,
    fontWeight: fontWeightIndex != null ? FontWeight.values[fontWeightIndex] : null,
    fontStyle: fontStyleIndex != null ? FontStyle.values[fontStyleIndex] : null,
    decoration: _decorationFromBits(dto.decoration),
    color: colorValue != null ? Color(colorValue) : null,
  );
  style.isDropCaps = dto.isDropCaps;
  return style;
}

Future<HtmlContent> contentFromDto(ContentDto dto) async {
  final elementStyle = _elementStyleFromDto(dto.elementStyle);
  final blockStyle = _blockStyleFromDto(dto.blockStyle, elementStyle);

  switch (dto) {
    case TextContentDto text:
      return TextContent(
        blockStyle: blockStyle,
        elementStyle: elementStyle,
        text: text.text,
      );
    case LinkContentDto link:
      final src = await contentFromDto(link.src);
      final footnotes = <HtmlContent>[];
      for (final item in link.footnotes) {
        footnotes.add(await contentFromDto(item));
      }
      final linkContent = LinkContent(
        blockStyle: blockStyle,
        elementStyle: elementStyle,
        src: src,
        href: link.href,
      );
      linkContent.footnotes = footnotes;
      return linkContent;
    case LineBreakDto _:
      return LineBreak(blockStyle: blockStyle, elementStyle: elementStyle);
    case ParagraphBreakDto _:
      return ParagraphBreak(blockStyle: blockStyle, elementStyle: elementStyle);
    case ImageBytesDto image:
      final bytes = image.bytes;
      final imageObj = await _decodeImage(bytes);
      return ImageContent(blockStyle: blockStyle, elementStyle: elementStyle, image: imageObj);
    default:
      throw StateError('Unknown content type: ${dto.runtimeType}');
  }
}

Future<List<HtmlContent>> contentsFromMapList(List<dynamic> data) async {
  final contents = <HtmlContent>[];
  for (final item in data) {
    final dto = ContentDto.fromJson((item as Map).cast<String, dynamic>());
    contents.add(await contentFromDto(dto));
  }
  return contents;
}
