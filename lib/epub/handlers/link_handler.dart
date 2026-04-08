import 'dart:ui';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/parser/isolates/worker_slot.dart';
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

    ElementStyle elementStyle = ElementStyle(parentStyle: parentElementStyle);
    await elementStyle.parseElement(element: element,);
    // TODO: I want to highlight footnotes, this will also highlight standard links, but see how it looks before making a decision. Given
    // this will normally relate to chapter headings, I don't think it will make a difference.
    elementStyle.setTextStyle(weight: FontWeight.w700);

    BlockStyle blockStyle = BlockStyle(elementStyle: elementStyle, parentStyle: parentBlockStyle);
    await blockStyle.parseElement(element: element,);

    // Override the block alignment as a Link is an inline element, not a block element. This was a problem with Terry Pratchett: A life in footnotes
    if (blockStyle.alignment == LineAlignment.left) {
      blockStyle.alignment = LineAlignment.justify;
    }

    if (node.children.isNotEmpty) {
      LinkCache cache = GetIt.instance.get<LinkCache>();
      List<HtmlContent>? childElements = await node.firstChild!.handler?.processElement(node: node.firstChild!, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
      String? href = node.getAttribute('href');
      String?   id = node.getAttribute('id');

      // Sometimes the Link id is registered against the parent element.
      id ??= element.parent?.getAttribute('id');

      if (childElements != null && childElements.isNotEmpty) {
        for (var child in childElements) {
          ElementSize size = switch (child) {
            ImageContent ic => await WorkerSlot.measureImageInMainThread(ic.image, ic.bytes),
            TextContent  tc => await WorkerSlot.measureTextInMainThread(tc.text, tc.elementStyle.textStyle),
                          _ => ElementSize(ascent: 0, descent: 0, width: 50, height: 50) // Just to stop analysis warnings; should never be hit!
          };

          LinkContent lc = LinkContent(blockStyle: blockStyle, elementStyle: elementStyle, src: child, href: href!, width: size.width, height: size.height);

          // Process Footnotes, if required.
          if (child is TextContent) {
            if (child.text.isFootnote || element.getAttribute('vertical-align') == "super") {
              child.elementStyle.setTextStyle(weight: FontWeight.w500, decoration: TextDecoration.none);
              
              if (!cache.contains(id)) {
                cache.add(id);
              }

              var (fnFile, fnRef) = href.splitReference;
              if (!cache.contains(fnRef)) {
                EpubParser parser = GetIt.instance.get<EpubParser>();
                XmlNode? footnote = parser.getFootnote(fnFile, fnRef);
                if (footnote != null) {
                  List<HtmlContent>? fnElements = await footnote.handler?.processElement(node: footnote,);
                  if (fnElements?.isNotEmpty ?? false) {
                    lc.addFootnotes(fnElements!);
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
