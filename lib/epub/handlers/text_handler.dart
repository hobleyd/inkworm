import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("TextHandler")
@Singleton(as: HtmlHandler)
class TextHandler extends HtmlHandler {
  TextHandler() {
    HtmlHandler.registerHandler(XmlNodeType.TEXT.name.toLowerCase(), this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlText element = node as XmlText;

    if (element.value.trim().isEmpty) {
      return [];
    }

    //debugPrint('TEXT_HANDLER: ${element.value}: $parentElementStyle');
    List<HtmlContent> elements = [];
    elements.add(TextContent(blockStyle: parentBlockStyle!, elementStyle: parentElementStyle!, text: element.value,),);

    return elements;
  }
}