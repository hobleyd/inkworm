import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../elements/link_element.dart';
import '../styles/block_style.dart';
import 'build_page.dart';
import 'line.dart';

class LinkHitArea {
  final Rect rect;
  final int chapterIndex;

  LinkHitArea({required this.rect, required this.chapterIndex});
}

class Page {
  List<Line> lines = [];
  List<Line> footnotes = [];
  List<PageBackground> backgrounds = [];
  List<LinkHitArea> links = [];

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
  }

  void addLine(Line line) {
    lines.add(line);
    _collectLinkHitAreas(line);
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

  bool willFitHeight(Line line) {
    return (currentBottomYPos + line.maxLineHeight) <= pageHeight;
  }
}

class PageBackground {
  final Color color;
  final Rect rect;

  PageBackground({required this.color, required this.rect});
}
