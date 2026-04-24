
import 'dart:typed_data';

import '../elements/image_element.dart';
import '../elements/line_element.dart';
import 'html_content.dart';

class ImageContent extends HtmlContent {
  final String image;
  final Uint8List bytes;
  final double requiredWidth;
  final double requiredHeight;

  @override
  Iterable<LineElement> get elements => [ImageElement(image: this, height: requiredHeight, width: requiredWidth)];

  const ImageContent({
    required super.blockStyle,
    required super.elementStyle,
    required super.width,
    required super.height,
    required this.image,
    required this.bytes,
    required this.requiredHeight,
    required this.requiredWidth,
  });

  @override
  String toString() {
    return 'IMG: orig: $width/$height: resized: ${elements.first.width}/${elements.first.height}';
  }
}
