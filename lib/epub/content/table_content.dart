import '../elements/line_element.dart';
import 'html_content.dart';

class TableColumnContent extends HtmlContent {
  final HtmlContent src;
  final String href;
  final List<HtmlContent> footnotes = [];

  bool get hasFootnotes => footnotes.isNotEmpty;

  @override
  Iterable<LineElement> get elements => src.elements;

  TableColumnContent({required super.blockStyle, required super.elementStyle, required super.width, required super.height, required this.src, required this.href});

  void addFootnotes(List<HtmlContent> notes) {
    footnotes.clear();
    footnotes.addAll(notes);
  }

  @override
  String toString() {
    return '$src[$href] -> $footnotes: $blockStyle, $elementStyle';
  }
}
