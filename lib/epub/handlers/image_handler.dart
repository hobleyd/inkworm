import 'dart:async';
import 'dart:typed_data';

import 'package:get_it/get_it.dart';
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

    ElementStyle elementStyle = ElementStyle(parentStyle: parentElementStyle);
    await elementStyle.parseElement(element: element, );

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle, parentStyle: parentBlockStyle);
    await blockStyle.parseElement(element: element, );

    String? src = element.getAttribute('src');
    src ??= element.getAttribute('xlink:href');
    if (src != null) {
      final Uint8List    bytes = GetIt.instance.get<EpubParser>().bookArchive!.getContentAsBytes(src);
      final ElementSize result = await WorkerSlot.measureImageInMainThread(src, bytes);

      elements.add(ImageContent(blockStyle: blockStyle, elementStyle: elementStyle, image: src, bytes: bytes, width: result.width, height: result.height));
    }
    return elements;
  }
}
