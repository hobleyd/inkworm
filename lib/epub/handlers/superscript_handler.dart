import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/link_content.dart';
import '../parser/epub_parser.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("SuperscriptHandler")
@Singleton(as: HtmlHandler)
class SuperscriptHandler extends HtmlHandler {
  SuperscriptHandler() {
    HtmlHandler.registerHandler('sup', this);
  }

  // <sup><a href="9780063021440_Footnote_1.xhtml#rfn1" id="fn1">*</a></sup>
  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;

    List<HtmlContent> elements = [];

    ElementStyle elementStyle = ElementStyle();
    elementStyle.parseElement(element: element, parentStyle: parentElementStyle);
    elementStyle.textStyle = elementStyle.textStyle.copyWith(fontSize: elementStyle.textStyle.fontSize! * 0.6);

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle);
    blockStyle.parseElement(element: element, parentStyle: parentBlockStyle);

    if (node.children.isNotEmpty) {
      List<HtmlContent>? childElements = await node.firstChild!.handler?.processElement(node: node.firstChild!, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
      if (childElements != null) {
        for (var child in childElements) {
          if (child is LinkContent) {
            // If we have a Link in a Superscript, this will be a footnote. Find the footnote, so we can display it on the page.
            EpubParser parser = GetIt.instance.get<EpubParser>();
            XmlNode? footnote = parser.getFootnote(child.href);
            if (footnote != null) {
              footnote = footnote.parent!;
              List<HtmlContent>? fnElements = await footnote.handler?.processElement(node: footnote, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
              if (fnElements != null) {
                child.footnote = fnElements;
              }
            }
          }
          elements.add(child);
        }
      }
    }

    return elements;
  }
}