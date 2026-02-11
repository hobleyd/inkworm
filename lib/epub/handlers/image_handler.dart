import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/image_bytes_content.dart';
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

  Future<ui.Image> createImageFromUint8List(Uint8List imageData) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(imageData, (ui.Image image) {
      completer.complete(image);
    });
    return completer.future;
  }
  
  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;
    List<HtmlContent> elements = [];

    ElementStyle elementStyle = ElementStyle();
    await elementStyle.parseElement(element: element, parentStyle: parentElementStyle);

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle);
    await blockStyle.parseElement(element: element, parentStyle: parentBlockStyle);

    final parser = GetIt.instance.get<EpubParser>();
    final bytes = parser.bookArchive!.getContentAsBytes(element.getAttribute('src')!);
    if (parser.decodeImages) {
      ui.Image img = await createImageFromUint8List(bytes);
      elements.add(ImageContent(blockStyle: blockStyle, elementStyle: elementStyle, image: img));
    } else {
      elements.add(ImageBytesContent(blockStyle: blockStyle, elementStyle: elementStyle, bytes: bytes));
    }

    return elements;
  }
}
