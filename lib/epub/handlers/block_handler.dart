import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import 'html_handler.dart';

@Named("BlockHandler")
@Singleton(as: HtmlHandler)
class BlockHandler extends HtmlHandler {
  BlockHandler() {
    HtmlHandler.registerHandler('p', this);
    HtmlHandler.registerHandler('h1', this);
    HtmlHandler.registerHandler('h2', this);
    HtmlHandler.registerHandler('h3', this);
    HtmlHandler.registerHandler('h4', this);
    HtmlHandler.registerHandler('h5', this);
    HtmlHandler.registerHandler('h6', this);
    HtmlHandler.registerHandler('li', this);
    HtmlHandler.registerHandler('div', this);
    HtmlHandler.registerHandler('blockquote', this);
  }

  @override
  Future<List<HtmlContent>> processElement(XmlElement element) async {
    debugPrint('BLOCK_HANDLER: ${element.name}: ${element.attributes}');
    List<HtmlContent> elements = [];

    BlockStyle style = BlockStyle(element);
    final String elementText = element.innerText.trim();
    if (elementText.isNotEmpty) {
      elements.add(TextContent(blockStyle: style, span: TextSpan(text: element.innerText, style: style.elementStyle.textStyle)));
    }

    for (var child in element.childElements) {
      debugPrint('CHILD_HANDLER: ${child.name}/${child.name.local}: ${child.attributes}');

      List<HtmlContent>? childElements = await HtmlHandler.getHandler(child.name.local)?.processElement(child);
      if (childElements != null) {
        elements.addAll(childElements);
      }
    }

    return elements;
  }
}