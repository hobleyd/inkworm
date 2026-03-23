import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../epub/content/text_content.dart';
import '../models/page_size.dart';
import '../epub/structure/line.dart';
import '../epub/elements/line_element.dart';

class PageRenderer extends CustomPainter {
  List<Line> lines = [];
  List<Line> footnotes = [];
  bool needsRepaint = true;

  PageRenderer({required this.lines, required this.footnotes});

  void paintLine(Canvas canvas, Line line) {
    double xPos = line.leftIndent + line.textIndent + line.dropCapsIndent;
    for (LineElement el in line.elements) {
      double yPos = line.yPosOnPage;
      if (el.alignToBaseline && line.baselineAdjust > 0) {
        yPos -= line.baselineAdjust;
        yPos += (el.element as TextContent).descent;
      }
      el.paint(canvas, el.alignToBaseline ? line.maxHeight : line.maxHeight - line.baselineAdjust, xPos, yPos);
      xPos += el.width;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // This is a little icky and should not be down in here; but I need the Canvas size and this is the only
    // way I can find to get it accurately!
    PageSize pageSize = GetIt.instance.get<PageSize>();
    pageSize.update(canvasWidth: size.width, canvasHeight: size.height,);

    canvas.clipRect(Offset(0, 0) & size);

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