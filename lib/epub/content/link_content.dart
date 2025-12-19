import '../elements/line_element.dart';
import 'html_content.dart';

class LinkContent extends HtmlContent {
  final HtmlContent src;
  final String href;
  List<HtmlContent> footnotes = [];

  @override
  Iterable<LineElement> get elements => src.elements;

  LinkContent({required super.blockStyle, required super.elementStyle, required this.src, required this.href});

  @override
  String toString() {
    return '$src[$href]: $blockStyle, $elementStyle';
  }
}
