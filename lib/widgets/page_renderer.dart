import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/constants.dart';
import '../epub/elements/line.dart';
import '../epub/elements/line_element.dart';
import '../epub/epub.dart';

class PageRenderer extends CustomPainter {
  final bool useTextPainter = true;
  List<Line> lines = [];

  late WidgetRef _ref;

  PageRenderer(WidgetRef ref, int pageNumber) {
    _ref = ref;

    if (ref.read(epubProvider).chapters.isNotEmpty) {
      lines = ref.read(epubProvider).chapters[0][pageNumber]!.lines;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ref.read(pageConstantsProvider.notifier).setConstraints(width: size.width, height: size.height);
    // DEBUGGING: canvas.drawRect(Offset(0, 0) & size, Paint()..color = Colors.red[100]!);
    canvas.clipRect(Offset(0, 0) & size);

    for (Line line in lines) {
      double xPos = line.leftIndent + line.textIndent + line.dropCapsIndent;
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