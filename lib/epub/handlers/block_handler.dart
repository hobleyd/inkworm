import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/content/paragraph_break.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("BlockHandler")
@Singleton(as: HtmlHandler)
class BlockHandler extends HtmlHandler {
  BlockHandler() {
    HtmlHandler.registerHandler('html', this);
    HtmlHandler.registerHandler('head', this);
    HtmlHandler.registerHandler('body', this);
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
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;

    List<HtmlContent> elements = [];

    ElementStyle elementStyle = ElementStyle();
    elementStyle.parseElement(element: element, parentStyle: parentElementStyle);

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle);
    blockStyle.parseElement(element: element, parentStyle: parentBlockStyle);

    //debugPrint('BLOCK_HANDLER: ${element.name}: ${element.attributes}: $blockStyle, $elementStyle');
    for (var child in node.children) {
      List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
      if (childElements != null) {
        elements.addAll(childElements);
      }
    }

    elements.add(ParagraphBreak(blockStyle: blockStyle, elementStyle: elementStyle));

    return elements;
  }
}