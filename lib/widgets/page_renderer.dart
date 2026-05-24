import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../epub/structure/line.dart';
import '../epub/structure/page.dart';
import '../epub/elements/line_element.dart';
import '../epub/styles/element_style.dart';

class PageRenderer extends CustomPainter {
  List<Line> lines = [];
  List<Line> footnotes = [];
  List<PageBackground> backgrounds = [];
  List<WordHitArea> words = [];
  int? selectionStart;
  int? selectionEnd;
  bool needsRepaint = false;

  PageRenderer({
    required this.lines,
    required this.footnotes,
    required this.backgrounds,
    this.words = const [],
    this.selectionStart,
    this.selectionEnd,
  });

  void paintLine(Canvas canvas, Line line) {
    final bool middleAlign = line.elements.any((el) => el.verticalAlignment == VerticalAlignment.middle);
    double xPos = line.leftIndent + line.textIndent + line.dropCapsIndent;
    for (LineElement el in line.elements) {
      double yPos = line.yPosOnPage;
      if (el.verticalAlignment == VerticalAlignment.baseline && line.baselineAdjust > 0 && el.ascent == 0) {
        yPos -= line.baselineAdjust;
      } else if (middleAlign) {
        yPos += (line.lineHeight - el.height) / 2;
      } else if (el.ascent > 0 && line.maxAscent > el.ascent && el.verticalAlignment != VerticalAlignment.top) {
        yPos += line.maxAscent - el.ascent;
      }
      el.paint(canvas, el.verticalAlignment == VerticalAlignment.baseline ? line.lineHeight : line.lineHeight - line.baselineAdjust, xPos, yPos);
      xPos += el.width;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset(0, 0) & size);

    for (final background in backgrounds) {
      canvas.drawRect(background.rect, Paint()..color = background.color);
    }

    _paintSelection(canvas);

    for (Line line in lines) {
      paintLine(canvas, line);
    }

    for (Line line in footnotes) {
      paintLine(canvas, line);
    }

    _paintHandles(canvas);
  }

  void _paintSelection(Canvas canvas) {
    if (selectionStart == null || selectionEnd == null || words.isEmpty) return;

    final lo = math.min(selectionStart!, selectionEnd!);
    final hi = math.min(math.max(selectionStart!, selectionEnd!), words.length - 1);

    final paint = Paint()
      ..color = const Color(0x402196F3)
      ..style = PaintingStyle.fill;

    // Group selected words by their top y-position (same visual line) and draw a
    // single rect spanning from the leftmost to the rightmost word on each line.
    // This fills the inter-word gaps rather than leaving them un-highlighted.
    final Map<double, Rect> byLine = {};
    for (int i = lo; i <= hi; i++) {
      final r = words[i].rect;
      final existing = byLine[r.top];
      byLine[r.top] = existing == null
          ? r
          : Rect.fromLTRB(
              math.min(existing.left,   r.left),
              existing.top,
              math.max(existing.right,  r.right),
              math.max(existing.bottom, r.bottom),
            );
    }

    for (final rect in byLine.values) {
      canvas.drawRect(rect, paint);
    }
  }

  void _paintHandles(Canvas canvas) {
    if (selectionStart == null || selectionEnd == null || words.isEmpty) return;

    final lo = math.min(selectionStart!, selectionEnd!);
    final hi = math.min(math.max(selectionStart!, selectionEnd!), words.length - 1);

    const double radius = 8;
    final paint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;

    // Left handle: circle below the bottom-left of the start word.
    final leftAnchor = words[lo].rect.bottomLeft;
    canvas.drawCircle(Offset(leftAnchor.dx, leftAnchor.dy + radius), radius, paint);
    canvas.drawRect(Rect.fromLTWH(leftAnchor.dx - 1, words[lo].rect.top, 2, words[lo].rect.height), paint);

    // Right handle: circle below the bottom-right of the end word.
    final rightAnchor = words[hi].rect.bottomRight;
    canvas.drawCircle(Offset(rightAnchor.dx, rightAnchor.dy + radius), radius, paint);
    canvas.drawRect(Rect.fromLTWH(rightAnchor.dx - 1, words[hi].rect.top, 2, words[hi].rect.height), paint);
  }

  @override
  bool shouldRepaint(PageRenderer oldDelegate) {
    if (needsRepaint) {
      needsRepaint = false;
      return true;
    }
    return selectionStart != oldDelegate.selectionStart || selectionEnd != oldDelegate.selectionEnd;
  }
}
