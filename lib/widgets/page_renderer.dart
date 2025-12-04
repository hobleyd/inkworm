import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../models/page_size.dart';
import '../epub/elements/line.dart';
import '../epub/elements/line_element.dart';
import '../providers/epub.dart';
import '../models/epub_book.dart';

class PageRenderer extends CustomPainter {
  List<Line> lines = [];

  PageRenderer(WidgetRef ref, int chapterNumber, int pageNumber) {
    EpubBook book = ref.read(epubProvider);
    lines = book.chapters.elementAtOrNull(chapterNumber)?[pageNumber]?.lines ?? [];
  }

  @override
  void paint(Canvas canvas, Size size) {
    // This is a little icky and should not be down in here; but I need the Canvas size and this is the only
    // way I can find to get it accurately!
    PageSize pageSize = GetIt.instance.get<PageSize>();
    pageSize.update(canvasWidth: size.width, canvasHeight: size.height);

    canvas.clipRect(Offset(0, 0) & size);

    for (Line line in lines) {
      //debugPrint('$line');
      double xPos = line.leftIndent + line.textIndent + line.dropCapsIndent;
      for (LineElement el in line.elements) {
        el.paint(canvas, line.height, xPos, line.yPos);
        xPos += el.width;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // Because a Book is immutable, there is no need for any complex repainting logic
    // as the only time a repaint will be required is if the page changes and this will
    // trigger a repaint through the Riverpod state management.
    return false;
  }
}