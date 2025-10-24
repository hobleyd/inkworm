import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

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
  InlineSpan processElement(XmlElement element) {
    debugPrint('BLOCK_HANDLER: ${element.name}: ${element.attributes}');

    BlockStyle style = BlockStyle(element);

    for (var child in element.childElements) {
      HtmlHandler.getHandler(child.name.local)?.processElement(element);
    }

    return TextSpan(text: element.innerText);
  }
}