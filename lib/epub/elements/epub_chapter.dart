import '../content/html_content.dart';
import '../content/image_content.dart';
import '../content/text_content.dart';
import '../styles/block_style.dart';
import 'epub_page.dart';
import 'line.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter {
  final int chapterNumber;
  bool newParagraphRequired = false;

  final List<EpubPage> _pages = [];

  EpubChapter({required this.chapterNumber,});

  EpubPage? operator [](int index) => _pages[index];

  void addContentToCurrentPage(HtmlContent content) {
    if (_pages.isEmpty) {
      _pages.add(EpubPage());
    }

    if (content is TextContent) {
      List<Line> overflow = _pages.last.addText(newParagraphRequired, content, []);
      newParagraphRequired = false;
      if (overflow.isNotEmpty) {
        _pages.add(EpubPage());
        _pages.last.addLines(overflow);
      }
    } else if (content is ImageContent) {
      _pages.last.addImage(content, false);
    } else {
      if (_pages.last.getActiveLines().isNotEmpty) {
        _pages.last.getActiveLines().last.completeParagraph();
      }
      newParagraphRequired = true;
    }
  }

  void clear() {
    for (var page in _pages) {
      page.clear();
    }

    _pages.clear();
  }
}