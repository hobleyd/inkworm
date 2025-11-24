import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/constants.dart';
import '../epub/elements/epub_chapter.dart';
import '../epub/elements/line.dart';
import '../epub/elements/line_element.dart';
import '../epub/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';
import '../providers/progress.dart';

class PageRenderer extends CustomPainter {
  late WidgetRef _ref;
  Timer? _runOnce;

  final bool useTextPainter = true;
  List<Line> lines = [];
  late ReadingProgress progress;

  PageRenderer(WidgetRef ref) {
    _ref = ref;

    EpubBook book = ref.watch(epubProvider);
    var progressAsync = ref.watch(progressProvider(book.uri));

    if (progressAsync.hasValue) {
      progress = progressAsync.value!;

      List<EpubChapter> chapters = ref.read(epubProvider).chapters;
      lines = chapters.elementAtOrNull(progress.chapterNumber)?[progress.pageNumber]?.lines ?? [];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // This is a little icky and should not be down in here; but I need the Canvas size and this is the only
    // way I can find to get it accurately!
    bool sizeChanged = _ref.read(pageConstantsProvider.notifier).setConstraints(width: size.width, height: size.height);
    if (sizeChanged) {
      _reparseBook();
    }
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
    return true;
  }

  void _reparseBook() {
    _runOnce?.cancel();

    _runOnce = Timer(Duration(milliseconds: 500), () {
      Future.delayed(Duration(seconds: 0), () => _ref.read(epubProvider.notifier).parse(progress.chapterNumber));
    });
  }
}