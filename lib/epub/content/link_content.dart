import '../elements/link_element.dart';
import '../elements/line_element.dart';
import '../elements/separators/separator.dart';
import 'html_content.dart';

class LinkContent extends HtmlContent {
  final HtmlContent src;
  final String href;
  final int? navigableChapter;
  final List<HtmlContent> footnotes = [];

  bool get hasFootnotes => footnotes.isNotEmpty;

  @override
  Iterable<LineElement> get elements {
    if (navigableChapter == null) return src.elements;
    return src.elements.map((el) {
      if (el is Separator) return el;
      return LinkElement(src: el, href: href, chapterIndex: navigableChapter!, width: el.width, height: el.height);
    });
  }

  LinkContent({required super.blockStyle, required super.elementStyle, required super.width, required super.height, required this.src, required this.href, this.navigableChapter});

  void addFootnotes(List<HtmlContent> notes) {
    footnotes.clear();
    footnotes.addAll(notes);
  }

  @override
  String toString() {
    return '$src[$href] -> $footnotes: $blockStyle, $elementStyle';
  }
}
