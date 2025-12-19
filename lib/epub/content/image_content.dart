import 'dart:ui' as ui;

import '../elements/image_element.dart';
import '../elements/line_element.dart';
import 'html_content.dart';

class ImageContent extends HtmlContent {
  final ui.Image image;

  double get height => image.height.toDouble();
  double get width => image.width.toDouble();

  @override
  Iterable<LineElement> get elements => [ImageElement(image: this)];

  const ImageContent({required super.blockStyle, required super.elementStyle, required this.image});

  @override
  String toString() {
    return 'IMG: orig: $width/$height: resized: ${elements.first.width}/${elements.first.height}';
  }
}
