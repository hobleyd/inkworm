import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../styles/block_style.dart';

@immutable
abstract class HtmlContent {
  final BlockStyle blockStyle;

  const HtmlContent({required this.blockStyle,});
}