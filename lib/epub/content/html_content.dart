import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../elements/line_element.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';

@immutable
abstract class HtmlContent {
  final BlockStyle blockStyle;
  final ElementStyle elementStyle;

  Iterable<LineElement> get elements;
  LineAlignment? get alignment  => blockStyle.alignment;
  double?        get leftIndent => blockStyle.leftIndent;
  bool           get isDropCaps => elementStyle.isDropCaps ?? false;

  const HtmlContent({required this.blockStyle, required this.elementStyle});
}