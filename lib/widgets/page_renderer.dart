import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkworm/epub/constants.dart';
import 'package:inkworm/epub/elements/separators/space_separator.dart';

import '../epub/elements/line.dart';
import '../epub/elements/line_element.dart';
import '../epub/epub.dart';

class PageRenderer extends CustomPainter {
  final bool useTextPainter = true;
  List<Line> lines = [];

  PageRenderer(WidgetRef ref, int pageNumber) {
    lines = ref.read(epubProvider)[0][pageNumber].lines;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset(0, 0) & size);

    for (Line line in lines) {
      double xPos = PageConstants.leftIndent + line.textIndent;
      for (LineElement el in line.elements) {
        el.paint(canvas, xPos, line.yPos);
        xPos += el.width;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true; // Just for example, in real environment should be implemented!
  }
}