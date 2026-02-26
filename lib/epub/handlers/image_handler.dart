import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/parser/epub_parser_worker.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/image_content.dart';
import '../parser/epub_parser.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("ImageHandler")
@Singleton(as: HtmlHandler)
class ImageHandler extends HtmlHandler {
  ImageHandler() {
    HtmlHandler.registerHandler('img', this);
  }
  
  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;
    List<HtmlContent> elements = [];

    ElementStyle elementStyle = ElementStyle();
    elementStyle.parseElement(element: element, parentStyle: parentElementStyle);

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle);
    blockStyle.parseElement(element: element, parentStyle: parentBlockStyle);

    final String src = element.getAttribute('src')!;
    final Uint8List bytes = GetIt.instance
        .get<EpubParser>()
        .bookArchive!
        .getContentAsBytes(src);

    Map<String, double> result = await EpubParserWorker.measureImageInMainThread(src, bytes);
    elements.add(ImageContent(blockStyle: blockStyle, elementStyle: elementStyle, image: src, width: result['width']!, height: result['height']!));

    return elements;
  }
}
