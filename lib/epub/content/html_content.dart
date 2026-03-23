import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../elements/line_element.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';

@immutable
abstract class HtmlContent {
  final BlockStyle blockStyle;
  final ElementStyle elementStyle;
  final double height;
  final double width;

  Iterable<LineElement> get elements;

  LineAlignment? get alignment    => blockStyle.alignment;
  double?        get leftIndent   => (blockStyle.leftIndent ?? 0) + blockStyle.marginLeft;
  bool           get isDropCaps   => elementStyle.isDropCaps ?? false;
  double         get marginLeft   => blockStyle.marginLeft;
  double         get marginRight  => blockStyle.marginRight;
  double         get marginTop    => blockStyle.marginTop;
  double         get marginBottom => blockStyle.marginBottom;

  const HtmlContent({required this.blockStyle, required this.elementStyle, required this.height, required this.width});
}