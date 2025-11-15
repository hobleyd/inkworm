import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("InlineHandler")
@Singleton(as: HtmlHandler)
class InlineHandler extends HtmlHandler {
  InlineHandler() {
    HtmlHandler.registerHandler('b', this);
    HtmlHandler.registerHandler('i', this);
    HtmlHandler.registerHandler('span', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;

    ElementStyle elementStyle = ElementStyle();
    elementStyle.parseElement(element: element, parentStyle: parentElementStyle);

    //debugPrint('INLINE_HANDLER: ${element.name}: ${element.attributes}: $elementStyle');
    List<HtmlContent> elements = [];
    for (var child in node.children) {
      List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: parentBlockStyle, parentElementStyle: elementStyle);
      if (childElements != null) {
        elements.addAll(childElements);
      }
    }

    return elements;
  }
}