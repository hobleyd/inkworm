import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/content/margin_content.dart';
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

    if (blockStyle.display != null && blockStyle.display == "none") {
      return [];
    }

    // Add a Paragraph Break before the content if we need a top-margin!
    if (blockStyle.marginTop > 0) {
      elements.add(MarginContent(blockStyle: blockStyle.copyWith(topMargin: blockStyle.topMargin, bottomMargin: 0), elementStyle: elementStyle));
    }

    //debugPrint('BLOCK_HANDLER: ${element.name}: ${element.attributes}: $blockStyle, $elementStyle');
    for (var child in node.children) {
      if (child.shouldProcess) {
        List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
        if (childElements?.isNotEmpty ?? false) {
          elements.addAll(childElements!);
        }
      }
    }

    if (blockStyle.marginBottom > 0) {
      elements.add(MarginContent(blockStyle: blockStyle.copyWith(bottomMargin: blockStyle.bottomMargin, topMargin: 0), elementStyle: elementStyle));
    }

    // We always need a Paragraph Break after the content, as long as we are not in the HEAD of the page.
    if (element.localName != 'head' && element.localName != 'html') {
      elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(topMargin: 0, bottomMargin: 0), elementStyle: elementStyle));
    }

    return elements;
  }
}