import '../elements/line_element.dart';
import '../elements/link_element.dart';
import 'html_content.dart';

class LinkContent extends HtmlContent {
  final HtmlContent src;
  final String href;

  @override
  Iterable<LineElement> get elements => [LinkElement(src: src.elements.first, href: href)];

  const LinkContent({required super.blockStyle, required super.elementStyle, required this.src, required this.href});

  @override
  String toString() {
    return '$src[$href]: $blockStyle, $elementStyle';
  }
}
