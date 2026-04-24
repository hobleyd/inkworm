import 'dart:async';
import 'dart:typed_data';

import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:xml/xml.dart';

import '../../models/element_size.dart';
import '../content/html_content.dart';
import '../content/image_content.dart';
import '../parser/epub_parser.dart';
import '../parser/extensions.dart';
import '../parser/isolates/worker_slot.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

class ImageHandler extends HtmlHandler {
  ImageHandler() {
    HtmlHandler.registerHandler('img', this);
    HtmlHandler.registerHandler('image', this);
  }
  
  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;
    List<HtmlContent> elements = [];

    ElementStyle elementStyle = await ElementStyle.getElementStyle(element, parentElementStyle);
    BlockStyle blockStyle     = await   BlockStyle.getBlockStyle(element, elementStyle: elementStyle, parentStyle: parentBlockStyle,);

    if (blockStyle.display == "none") {
      return [];
    }

    String? src = element.getAttribute('src');
    src ??= element.getAttribute('xlink:href');

    if (src != null) {
      final Uint8List    bytes = GetIt.instance.get<EpubParser>().bookArchive!.getContentAsBytes(src);

      final ElementSize result = await WorkerSlot.measureImageInMainThread(src, bytes);

      double  requiredWidth = result.width;
      double requiredHeight = result.height;

      CssParser cssParser = GetIt.instance.get<CssParser>();
      String?  widthString = cssParser.getStringAttribute(element, elementStyle, 'width');
      String? heightString = cssParser.getStringAttribute(element, elementStyle, 'height');

      if (widthString != null) {
        if (widthString.endsWith('%')) {
          double percent = double.parse(widthString.substring(0, widthString.length-1)) / 100;
          requiredWidth = requiredWidth * percent;
          requiredHeight = requiredHeight * percent;
        } else if (heightString?.endsWith('%') ?? false) {
          double percent = double.parse(heightString!.substring(0, heightString.length-1)) / 100;
          requiredWidth = requiredWidth * percent;
          requiredHeight = requiredHeight * percent;
        } else {
          requiredWidth = double.parse(widthString  ?? '0');
          requiredHeight = double.parse(heightString ?? '0');
        }
      }

      elements.add(
        ImageContent(
          blockStyle: blockStyle,
          elementStyle: elementStyle,
          image: src,
          bytes: bytes,
          width: result.width,
          height: result.height,
          requiredHeight: requiredHeight > 0 ? requiredHeight : result.height,
          requiredWidth:   requiredWidth > 0 ? requiredWidth  : result.width,
        ),
      );
    }
    return elements;
  }
}
