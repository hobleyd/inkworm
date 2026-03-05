
import 'dart:typed_data';

import '../elements/image_element.dart';
import '../elements/line_element.dart';
import 'html_content.dart';

class ImageContent extends HtmlContent {
  String image;
  Uint8List bytes;

  @override
  Iterable<LineElement> get elements => [ImageElement(image: this, height: height, width: width)];

  ImageContent({
    required super.blockStyle,
    required super.elementStyle,
    required super.width,
    required super.height,
    required this.image,
    required this.bytes,
  });

  @override
  String toString() {
    return 'IMG: orig: $width/$height: resized: ${elements.first.width}/${elements.first.height}';
  }
}
