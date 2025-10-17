import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/constants.dart';
import '../epub/elements/line.dart';
import '../epub/elements/line_element.dart';

class PageRenderer extends CustomPainter {
  final bool useTextPainter = true;
  List<Line> lines = [];

  late WidgetRef _ref;

  PageRenderer(WidgetRef ref, int pageNumber) {
    _ref = ref;

    //if (ref.read(epubProvider).isNotEmpty) {
     // lines = ref.read(epubProvider)[0][pageNumber].lines;
    //}
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ref.read(pageConstantsProvider.notifier).setConstraints(width: size.width, height: size.height);
    canvas.clipRect(Offset(0, 0) & size);

    for (Line line in lines) {
      double xPos = PageConstants.leftIndent + line.textIndent;
      for (LineElement el in line.elements) {
        el.paint(canvas, line.height, xPos, line.yPos);
        xPos += el.width;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true; // Just for example, in real environment should be implemented!
  }
}