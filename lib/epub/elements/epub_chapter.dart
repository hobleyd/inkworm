import 'package:inkworm/epub/content/paragraph_break.dart';

import '../content/html_content.dart';
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

    if (content is ParagraphBreak) {
      if (_pages.last.getActiveLines().isNotEmpty) {
        _pages.last.getActiveLines().last.completeParagraph();
      }
      newParagraphRequired = true;
    } else {
      List<Line> overflow = _pages.last.addElement(newParagraphRequired, content, []);
      if (overflow.isNotEmpty) {
        _pages.add(EpubPage());
        _pages.last.addLines(overflow);
      }
      newParagraphRequired = false;
    }
  }

  void clear() {
    for (var page in _pages) {
      page.clear();
    }

    _pages.clear();
  }
}