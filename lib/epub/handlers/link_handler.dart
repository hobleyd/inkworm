import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/link_content.dart';
import '../content/text_content.dart';
import '../parser/epub_parser.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("LinkHandler")
@Singleton(as: HtmlHandler)
class LinkHandler extends HtmlHandler {
  LinkHandler() {
    HtmlHandler.registerHandler('a', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;

    ElementStyle elementStyle = ElementStyle();
    elementStyle.parseElement(element: element, parentStyle: parentElementStyle);

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle);
    blockStyle.parseElement(element: element, parentStyle: parentBlockStyle);

    if (node.children.isNotEmpty) {
      List<HtmlContent>? childElements = await node.firstChild!.handler?.processElement(node: node.firstChild!, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
      String? href = node.getAttribute('href');

      if (childElements != null && childElements.isNotEmpty) {
        LinkContent lc = LinkContent(blockStyle: blockStyle, elementStyle: elementStyle, src: childElements.first, href: href!);

        if (childElements.first is TextContent) {
          TextContent tc = childElements.first as TextContent;
          if (tc.text.isFootnote) {
            EpubParser parser = GetIt.instance.get<EpubParser>();
            XmlNode? footnote = parser.getFootnote(href);
            if (footnote != null) {
              List<HtmlContent>? fnElements = await footnote.handler?.processElement(node: footnote, );
              if (fnElements != null) {
                lc.footnotes = fnElements;
              }
            }
          }
        }
        return [lc];
      }
    }

    return [];
  }
}
