import 'dart:ui';

import 'package:flutter/material.dart';

import '../epub/content/text_content.dart';
import '../epub/structure/line.dart';
import '../epub/styles/element_style.dart';
import '../epub/structure/page.dart';
import '../epub/elements/line_element.dart';

class PageRenderer extends CustomPainter {
  List<Line> lines = [];
  List<Line> footnotes = [];
  List<PageBackground> backgrounds = [];
  bool needsRepaint = false;

  PageRenderer({required this.lines, required this.footnotes, required this.backgrounds});

  void paintLine(Canvas canvas, Line line) {
    final bool middleAlign = line.elements.any((el) => el.verticalAlignment == VerticalAlignment.middle);
    double xPos = line.leftIndent + line.textIndent + line.dropCapsIndent;
    for (LineElement el in line.elements) {
      double yPos = line.yPosOnPage;
      if (el.verticalAlignment == VerticalAlignment.baseline && line.baselineAdjust > 0 && el.ascent == 0) {
        // Non-text element (e.g. image) with explicit baseline alignment: shift so its bottom sits on the baseline.
        yPos -= line.baselineAdjust;
      } else if (middleAlign) {
        yPos += (line.lineHeight - el.height) / 2;
      } else if (el.ascent > 0 && line.maxAscent > el.ascent) {
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

    for (Line line in lines) {
      paintLine(canvas, line);
    }

    for (Line line in footnotes) {
      paintLine(canvas, line);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // Because a Book is immutable, there is no need for any complex repainting logic
    // as the only time a repaint will be required is if the page changes and this will
    // trigger a repaint through the Riverpod state management.
    if (needsRepaint) {
      needsRepaint = false;
      return true;
    }
    return false;
  }
}
