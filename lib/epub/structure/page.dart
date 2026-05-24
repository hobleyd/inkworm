import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../elements/link_element.dart';
import '../elements/word_element.dart';
import '../styles/block_style.dart';
import 'build_page.dart';
import 'line.dart';

class LinkHitArea {
  final Rect rect;
  final int chapterIndex;

  LinkHitArea({required this.rect, required this.chapterIndex});
}

class WordHitArea {
  final Rect rect;
  final String text;

  WordHitArea({required this.rect, required this.text});
}

class Page {
  List<Line> lines = [];
  List<Line> footnotes = [];
  List<PageBackground> backgrounds = [];
  List<LinkHitArea> links = [];

  // Body and footnote words are kept separate because addFootnote() recalculates
  // y-positions for all footnote lines each time a footnote is added, so footnote
  // word rects must be rebuilt from scratch on every addFootnote() call.
  final List<WordHitArea> _bodyWords = [];
  final List<WordHitArea> _footnoteWords = [];

  // Combined list used by callers; body words precede footnote words.
  List<WordHitArea> get words =>
      _footnoteWords.isEmpty ? _bodyWords : [..._bodyWords, ..._footnoteWords];

  double dropCapsXPosition = 0;
  double dropCapsYPosition = 0;
  double currentBottomYPos = 0;
  double pageHeight = 0;

  Page();

  Line?  get currentLine        => lines.lastOrNull;
  bool   get isCurrentLineEmpty => currentLine?.isEmpty ?? true;

  set alignment(LineAlignment alignment) => currentLine!.alignment = alignment;

  void addBackground(PageBackground background) {
    backgrounds.add(background);
  }

  void addFootnote(Line line) {
    footnotes.add(line);
    PageSize size = GetIt.instance.get<PageSize>();
    pageHeight = size.canvasHeight - footnotes.totalHeight - BuildPage.footnoteMargin;

    double footnotesYPos = pageHeight + BuildPage.footnoteMargin;
    for (Line l in footnotes) {
      l.yPos = footnotesYPos;
      footnotesYPos += l.lineHeight;
    }

    // Rebuild footnote word hit areas now that all y-positions are finalised.
    _footnoteWords.clear();
    for (final l in footnotes) {
      _collectWordHitAreas(l, _footnoteWords);
    }
  }

  void addLine(Line line) {
    lines.add(line);
    _collectLinkHitAreas(line);
    _collectWordHitAreas(line, _bodyWords);
    currentBottomYPos += line.lineHeight - line.baselineAdjust;
  }

  void _collectLinkHitAreas(Line line) {
    double xPos = line.leftIndents;
    for (final el in line.elements) {
      if (el is LinkElement) {
        links.add(LinkHitArea(
          rect: Rect.fromLTWH(xPos, line.yPosOnPage, el.width, el.height),
          chapterIndex: el.chapterIndex,
        ));
      }
      xPos += el.width;
    }
  }

  void _collectWordHitAreas(Line line, List<WordHitArea> target) {
    double xPos = line.leftIndents;
    for (final el in line.elements) {
      if (el is WordElement && !el.isDropCaps) {
        target.add(WordHitArea(
          rect: Rect.fromLTWH(xPos, line.yPosOnPage, el.width, el.height),
          text: el.word.text,
        ));
      }
      xPos += el.width;
    }
  }

  int? wordIndexNearestTo(Offset point) {
    final all = words;
    if (all.isEmpty) return null;

    // Prefer words on the same visual line as the point.
    final onLine = all.where((w) => point.dy >= w.rect.top && point.dy < w.rect.bottom).toList();
    final pool = onLine.isNotEmpty ? onLine : all;

    final nearest = pool.reduce((a, b) {
      final da = (a.rect.center.dx - point.dx).abs() + (a.rect.center.dy - point.dy).abs();
      final db = (b.rect.center.dx - point.dx).abs() + (b.rect.center.dy - point.dy).abs();
      return da <= db ? a : b;
    });

    // Identity comparison: nearest is the same object as one element in all.
    return all.indexOf(nearest);
  }

  String selectedText(int start, int end) {
    final all = words;
    final lo = math.min(start, end);
    final hi = math.max(start, end);
    return all.sublist(lo, (hi + 1).clamp(0, all.length)).map((w) => w.text).join(' ');
  }

  bool willFitHeight(Line line) {
    return (currentBottomYPos + line.maxLineHeight) <= pageHeight;
  }
}

class PageBackground {
  final Color color;
  final Rect rect;

  PageBackground({required this.color, required this.rect});
}
