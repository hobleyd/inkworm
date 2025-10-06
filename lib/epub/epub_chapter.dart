import 'package:flutter/material.dart';

import 'epub_page.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter {
  final int chapterNumber;

  final List<EpubPage> _pages = [];

  EpubChapter({required this.chapterNumber,});

  operator [](int index) => _pages[index];

  void addTextToCurrentPage(TextSpan span) {
    if (_pages.isEmpty) {
      _pages.add(EpubPage());
    }

    TextSpan? overflow = _pages.last.addText(span, []);
    if (overflow != null) {
      _pages.add(EpubPage());
      addTextToCurrentPage(overflow);
    }
  }

  void clear() {
    for (var page in _pages) {
      page.clear();
    }

    _pages.clear();
  }
}