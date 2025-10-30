import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/image_content.dart';
import '../parser/epub_parser.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
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
  Future<List<HtmlContent>> processElement(XmlElement element) async {
    debugPrint('IMG_HANDLER: ${element.name}: ${element.attributes}');
    List<HtmlContent> elements = [];

    BlockStyle style = BlockStyle();
    style.parseElement(element);
    ui.Image img = await createImageFromUint8List(GetIt.instance.get<EpubParser>().bookArchive.getContentAsBytes(element.getAttribute('src')!));

    elements.add(ImageContent(blockStyle: style, image: img));

    return elements;
  }
}