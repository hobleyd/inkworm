import 'dart:typed_data';

import '../elements/line_element.dart';
import 'html_content.dart';

class ImageBytesContent extends HtmlContent {
  final Uint8List bytes;

  @override
  Iterable<LineElement> get elements => const [];

  const ImageBytesContent({required super.blockStyle, required super.elementStyle, required this.bytes});
}
