import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/paragraph_break.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

class TableHandler extends HtmlHandler {
  TableHandler() {
    HtmlHandler.registerHandler('table', this);
    HtmlHandler.registerHandler('thead', this);
    HtmlHandler.registerHandler('tbody', this);
    HtmlHandler.registerHandler('tfoot', this);
    HtmlHandler.registerHandler('tr', this);
    HtmlHandler.registerHandler('td', this);
    HtmlHandler.registerHandler('th', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    final XmlElement element = node as XmlElement;
    final String elementName = element.localName.toLowerCase();

    final ElementStyle elementStyle = ElementStyle(parentStyle: parentElementStyle);
    await elementStyle.parseElement(element: element);

    final BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle, parentStyle: parentBlockStyle);
    await blockStyle.parseElement(element: element);

    if (blockStyle.display == 'none') {
      return [];
    }

    return switch (elementName) {
      'table' => _processTable(element, blockStyle, elementStyle),
         'tr' => _processRow(element, blockStyle, elementStyle),
           _  => _processChildren(element, parentBlockStyle: blockStyle, parentElementStyle: elementStyle,),
    };
  }

  Future<List<HtmlContent>> _processTable(XmlElement element, BlockStyle blockStyle, ElementStyle elementStyle) async {
    final List<HtmlContent> elements = [
      ParagraphBreak(blockStyle: blockStyle.copyWith(bottomMargin: 0), elementStyle: elementStyle, width: 0, height: 0,),
    ];

    elements.addAll(await _processChildren(element, parentBlockStyle: blockStyle, parentElementStyle: elementStyle,));

    elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(topMargin: 0), elementStyle: elementStyle, width: 0, height: 0,),);

    return elements;
  }

  Future<List<HtmlContent>> _processRow(XmlElement element, BlockStyle blockStyle, ElementStyle elementStyle) async {
    final List<HtmlContent> elements = [];
    bool hasCellContent = false;

    for (final XmlNode child in element.children) {
      if (!child.shouldProcess) {
        continue;
      }

      final List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: blockStyle, parentElementStyle: elementStyle,);

      if (childElements == null || childElements.isEmpty) {
        continue;
      }

      if (hasCellContent) {
        elements.addAll(await _buildSeparator(blockStyle, elementStyle));
      }

      elements.addAll(childElements);
      hasCellContent = true;
    }

    if (elements.isNotEmpty) {
      elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(topMargin: 0, bottomMargin: 0), elementStyle: elementStyle, width: 0, height: 0,),);
    }

    return elements;
  }

  Future<List<HtmlContent>> _processChildren(XmlElement element, {required BlockStyle parentBlockStyle, required ElementStyle parentElementStyle,}) async {
    final List<HtmlContent> elements = [];

    for (final XmlNode child in element.children) {
      if (!child.shouldProcess) {
        continue;
      }

      final List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: parentBlockStyle, parentElementStyle: parentElementStyle,);

      if (childElements != null) {
        elements.addAll(childElements);
      }
    }

    return elements;
  }

  Future<List<HtmlContent>> _buildSeparator(BlockStyle blockStyle, ElementStyle elementStyle) async {
    final XmlText separator = XmlText(' | ');
    return await separator.handler?.processElement(node: separator, parentBlockStyle: blockStyle, parentElementStyle: elementStyle,) ?? [];
  }
}
