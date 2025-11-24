import 'package:inkworm/epub/content/text_content.dart';
import 'package:inkworm/epub/elements/link_element.dart';

import '../elements/line_element.dart';
import 'html_content.dart';

class LinkContent extends HtmlContent {
  final TextContent text;
  final String href;

  @override
  Iterable<LineElement> get elements => [LinkElement(text: text, href: href)];

  const LinkContent({required super.blockStyle, required super.elementStyle, required this.text, required this.href});

  @override
  String toString() {
    return '$text[$href]: $blockStyle, $elementStyle';
  }
}
