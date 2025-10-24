import 'package:flutter/material.dart';

import 'epub_page.dart';
import 'line.dart';

/*
 * A Chapter contains a list of Pages
 */
class EpubChapter {
  final int chapterNumber;

  final List<EpubPage> _pages = [];

  EpubChapter({required this.chapterNumber,});

  EpubPage? operator [](int index) => _pages[index];

  void addTextToCurrentPage(TextSpan span) {
    if (_pages.isEmpty) {
      _pages.add(EpubPage());
    }

    List<Line> overflow = _pages.last.addText(span, []);
    if (overflow.isNotEmpty) {
      _pages.add(EpubPage());
      _pages.last.addLines(overflow);
    }
  }

  void clear() {
    for (var page in _pages) {
      page.clear();
    }

    _pages.clear();
  }
}