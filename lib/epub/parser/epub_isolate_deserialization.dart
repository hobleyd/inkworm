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

BlockStyle _blockStyleFromMap(Map<String, Object?> map, ElementStyle elementStyle) {
  final style = BlockStyle(elementStyle: elementStyle);
  style.leftMargin = map['leftMargin'] as double?;
  style.rightMargin = map['rightMargin'] as double?;
  style.topMargin = map['topMargin'] as double?;
  style.bottomMargin = map['bottomMargin'] as double?;
  style.leftIndent = map['leftIndent'] as double?;
  final alignmentIndex = map['alignment'] as int?;
  if (alignmentIndex != null) {
    style.alignment = LineAlignment.values[alignmentIndex];
  }
  style.maxHeight = map['maxHeight'] as double?;
  style.maxWidth = map['maxWidth'] as double?;
  return style;
}

ElementStyle _elementStyleFromMap(Map<String, Object?> map) {
  final style = ElementStyle();
  final fontWeightIndex = map['fontWeight'] as int?;
  final fontStyleIndex = map['fontStyle'] as int?;
  final colorValue = map['color'] as int?;
  style.textStyle = TextStyle(
    fontSize: map['fontSize'] as double?,
    fontFamily: map['fontFamily'] as String?,
    fontWeight: fontWeightIndex != null ? FontWeight.values[fontWeightIndex] : null,
    fontStyle: fontStyleIndex != null ? FontStyle.values[fontStyleIndex] : null,
    decoration: _decorationFromBits(map['decoration'] as int?),
    color: colorValue != null ? Color(colorValue) : null,
  );
  style.isDropCaps = map['isDropCaps'] as bool?;
  return style;
}

Future<HtmlContent> contentFromMap(Map<String, Object?> map) async {
  final type = map['type'] as String?;
  if (type == null) {
    throw StateError('Missing content type');
  }

  final elementStyle = _elementStyleFromMap((map['elementStyle'] as Map).cast<String, Object?>());
  final blockStyle = _blockStyleFromMap((map['blockStyle'] as Map).cast<String, Object?>(), elementStyle);

  switch (type) {
    case 'text':
      return TextContent(
        blockStyle: blockStyle,
        elementStyle: elementStyle,
        text: map['text'] as String? ?? '',
      );
    case 'link':
      final src = await contentFromMap((map['src'] as Map).cast<String, Object?>());
      final footnotes = <HtmlContent>[];
      final rawFootnotes = map['footnotes'] as List? ?? const [];
      for (final item in rawFootnotes) {
        footnotes.add(await contentFromMap((item as Map).cast<String, Object?>()));
      }
      final link = LinkContent(
        blockStyle: blockStyle,
        elementStyle: elementStyle,
        src: src,
        href: map['href'] as String? ?? '',
      );
      link.footnotes = footnotes;
      return link;
    case 'line_break':
      return LineBreak(blockStyle: blockStyle, elementStyle: elementStyle);
    case 'paragraph_break':
      return ParagraphBreak(blockStyle: blockStyle, elementStyle: elementStyle);
    case 'image':
      final bytes = map['bytes'] as Uint8List;
      final image = await _decodeImage(bytes);
      return ImageContent(blockStyle: blockStyle, elementStyle: elementStyle, image: image);
    default:
      throw StateError('Unknown content type: $type');
  }
}

Future<List<HtmlContent>> contentsFromMapList(List<dynamic> data) async {
  final contents = <HtmlContent>[];
  for (final item in data) {
    contents.add(await contentFromMap((item as Map).cast<String, Object?>()));
  }
  return contents;
}
