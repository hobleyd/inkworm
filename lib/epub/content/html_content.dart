import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../styles/block_style.dart';
import '../styles/element_style.dart';

@immutable
abstract class HtmlContent {
  final BlockStyle blockStyle;
  final ElementStyle elementStyle;

  const HtmlContent({required this.blockStyle, required this.elementStyle});
}