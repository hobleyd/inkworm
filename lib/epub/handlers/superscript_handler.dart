import 'dart:ui';

import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/link_content.dart';
import '../parser/epub_parser.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

class SuperscriptHandler extends HtmlHandler {
  SuperscriptHandler() {
    HtmlHandler.registerHandler('sup', this);
  }

  // <sup><a href="9780063021440_Footnote_1.xhtml#rfn1" id="fn1">*</a></sup>
  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;

    List<HtmlContent> elements = [];

    ElementStyle elementStyle = await ElementStyle.getElementStyle(element, parentElementStyle);
    BlockStyle     blockStyle = await   BlockStyle.getBlockStyle(element, elementStyle: elementStyle, parentStyle: parentBlockStyle,);

    if (node.children.isNotEmpty) {
      List<HtmlContent>? childElements = await node.firstChild!.handler?.processElement(node: node.firstChild!, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
      if (childElements != null) {
        for (var child in childElements) {
          if (child is LinkContent) {
            child.elementStyle.setTextStyle(weight: FontWeight.w500, decoration: TextDecoration.none);

            // If we have a Link in a Superscript, this will be a footnote. Find the footnote, so we can display it on the page.
            var (fnFile, fnRef) = child.href.splitReference;
            EpubParser parser = GetIt.instance.get<EpubParser>();
            XmlNode? footnote = parser.getFootnote(fnFile, fnRef);
            if (footnote != null) {
              footnote = footnote.parent!;
              List<HtmlContent>? fnElements = await footnote.handler?.processElement(node: footnote, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
              if (fnElements?.isNotEmpty ?? false) {
                child.addFootnotes(fnElements!);
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
