import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/paragraph_break.dart';
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

    // We want to add a new line for every block, obviously. But remove the bottom margin from this break and
    // keep it in for the break at the end of the block.
    elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(bottomMargin: 0), elementStyle: elementStyle));

    //debugPrint('BLOCK_HANDLER: ${element.name}: ${element.attributes}: $blockStyle, $elementStyle');
    for (var child in node.children) {
      if (child.shouldProcess) {
        List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
        if (childElements?.isNotEmpty ?? false) {
          for (var element in childElements!) {
            // Check for repeated, empty paragraphs and don't add multiples in.
            if (childElements.length == 2 && element is ParagraphBreak) {
              if (elements.length >= 2) {
                if (elements[elements.length - 2] == element || elements[elements.length - 1] == element) {
                  continue;
                }
              }
            }
            elements.add(element);
          }
        }
      }
    }

    // We always need a Paragraph Break after the content, as long as we are not in the HEAD of the page. Remove
    // the topMargin to match the break before the text.
    if (element.localName != 'head' && element.localName != 'html') {
      elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(topMargin: 0), elementStyle: elementStyle));
    }

    return elements;
  }
}