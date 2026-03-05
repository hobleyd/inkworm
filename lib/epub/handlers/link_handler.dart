import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/parser/epub_parser_worker.dart';
import 'package:xml/xml.dart';

import '../../models/element_size.dart';
import '../cache/link_cache.dart';
import '../content/html_content.dart';
import '../content/image_content.dart';
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

    List<HtmlContent> elements = [];

    ElementStyle elementStyle = ElementStyle();
    await elementStyle.parseElement(element: element, parentStyle: parentElementStyle);

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle);
    await blockStyle.parseElement(element: element, parentStyle: parentBlockStyle);

    // Override the block alignment as a Link is an inline element, not a block element. This was a problem with Terry Pratchett: A life in footnotes
    if (blockStyle.alignment == LineAlignment.left) {
      blockStyle.alignment = LineAlignment.justify;
    }

    if (node.children.isNotEmpty) {
      LinkCache cache = GetIt.instance.get<LinkCache>();
      List<HtmlContent>? childElements = await node.firstChild!.handler?.processElement(node: node.firstChild!, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
      String? href = node.getAttribute('href');
      String?   id = node.getAttribute('id');

      if (childElements != null && childElements.isNotEmpty) {
        for (var child in childElements) {
          ElementSize size = switch (child) {
            ImageContent ic => await EpubParserWorker.measureImageInMainThread(ic.image, ic.bytes),
            TextContent  tc => await EpubParserWorker.measureTextInMainThread(tc.text, tc.elementStyle.textStyle),
                          _ => ElementSize(width: 0, height: 0) // Just to stop analysis warnings; should never be hit!
          };

          LinkContent lc = LinkContent(blockStyle: blockStyle, elementStyle: elementStyle, src: child, href: href!, width: size.width, height: size.height);

          // Process Footnotes, if required.
          if (child is TextContent) {
            if (!cache.contains(id) && child.text.isFootnote || element.getAttribute('vertical-align') == "super") {
              lc.elementStyle.setBold();
              cache.add(id);

              var (fnFile, fnRef) = href.splitReference;
              if (!cache.contains(fnRef)) {
                EpubParser parser = GetIt.instance.get<EpubParser>();
                XmlNode? footnote = parser.getFootnote(fnFile, fnRef);
                if (footnote != null) {
                  List<HtmlContent>? fnElements = await footnote.handler?.processElement(node: footnote,);
                  if (fnElements != null) {
                    lc.footnotes = fnElements;
                  }
                }
              }
            }
          }
          elements.add(lc);
        }
      }
    }

    return elements;
  }
}
