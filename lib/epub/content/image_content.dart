import 'dart:ui' as ui;

import 'html_content.dart';

class ImageContent extends HtmlContent {
  final ui.Image image;

  double get height => image.height.toDouble();
  double get width => image.width.toDouble();

  const ImageContent({required super.blockStyle, required this.image});
}
