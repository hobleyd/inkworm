import 'dart:math';

import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/paragraph_break.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import '../styles/table_cell_style.dart';
import 'html_handler.dart';

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
    HtmlHandler.registerHandler('div', this);
    HtmlHandler.registerHandler('ol', this);
    HtmlHandler.registerHandler('li', this);
    HtmlHandler.registerHandler('blockquote', this);
    HtmlHandler.registerHandler('section', this);
    HtmlHandler.registerHandler('figure', this);
    HtmlHandler.registerHandler('hgroup', this);
    HtmlHandler.registerHandler('header', this);
    HtmlHandler.registerHandler('aside', this);
    HtmlHandler.registerHandler('svg', this);
    HtmlHandler.registerHandler('nav', this);
    HtmlHandler.registerHandler('td', this);
    HtmlHandler.registerHandler('th', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;

    ElementStyle elementStyle = await ElementStyle.getElementStyle(element, parentElementStyle);
    BlockStyle blockStyle = switch (element.localName) {
      'td' || 'th' => await TableCellStyle.getTableCellStyle(element, elementStyle: elementStyle, parentStyle: parentBlockStyle,),
                _  => await     BlockStyle.getBlockStyle(element, elementStyle: elementStyle, parentStyle: parentBlockStyle,),
    };

    if (blockStyle.display == "none") {
      return [];
    }

    // We want to add a new line for every block, obviously. But remove the bottom margin from this break and
    // keep it in for the break at the end of the block.
    final List<HtmlContent> elements = [
      ParagraphBreak(blockStyle: blockStyle.copyWith(bottomMargin: 0), elementStyle: elementStyle, width: 0, height: 0)
    ];

    for (var child in node.children) {
      if (child.shouldProcess && !_isParagraphEmpty(child)) {
        List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
        if (childElements?.isNotEmpty ?? false) {
          for (var el in childElements!) {
            if (el is ParagraphBreak && elements.last is ParagraphBreak) {
              // support margin collapsing if required.
              if (el.marginTop > 0 && elements.last.marginBottom > 0) {
                elements.last.blockStyle.bottomMargin = max(elements.last.marginBottom, el.marginTop);
                continue;
              }
            }
            elements.add(el);
          }
        }
      }
    }

    // We always need a Paragraph Break after the content, as long as we are not in the HEAD of the page. Remove
    // the topMargin to match the break before the text.
    if (element.localName != 'head' && element.localName != 'html') {
      elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(topMargin: 0), elementStyle: elementStyle, width: 0, height: 0));
    }

    return elements;
  }

  bool _isParagraphEmpty(XmlNode node) {
    if (node is XmlElement && node.localName == 'p') {
      // If there are child elements (not just text nodes), it's not empty
      if (node.children.any((child) => child is XmlElement)) {
        return false;
      }

      // Check if there's any text content or entities
      for (var child in node.children) {
        if (child is XmlText) {
          // Check the raw text (before entity decoding)
          if (child.value.trimPreservingNbsp().isNotEmpty) {
            return false;
          }
        }
      }

      return true;
    }

    return false;
  }
}
