import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/content/paragraph_break.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/line_break.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("LineBreakHandler")
@Singleton(as: HtmlHandler)
class LineBreakHandler extends HtmlHandler {
  LineBreakHandler() {
    HtmlHandler.registerHandler('br', this);
    HtmlHandler.registerHandler('br/', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    List<HtmlContent> elements = [];

    elements.add(LineBreak(blockStyle: parentBlockStyle!, elementStyle: parentElementStyle!));

    return elements;
  }
}