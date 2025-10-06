import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/epub.dart';
import '../epub/paragraph.dart';

class PageRenderer extends CustomPainter {
  final bool useTextPainter = false;
  List<Paragraph> spans = [];

  PageRenderer(WidgetRef ref, int pageNumber) {
    spans = Epub.instance[0][pageNumber].spans;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset(0, 0) & size, Paint()..color = Colors.red[100]!);
    canvas.clipRect(Offset(0, 0) & size);

    for (Paragraph para in spans) {
      if (useTextPainter) {
        final TextPainter textPainter = TextPainter(text: para.span, textAlign: TextAlign.justify, textDirection: TextDirection.ltr);
        textPainter.layout(maxWidth: Epub.instance.canvasWidth - Epub.instance.leftIndent - Epub.instance.rightIndent);
        textPainter.paint(canvas, Offset(Epub.instance.leftIndent, para.y));
      }
      else {
        final ui.ParagraphBuilder paragraphBuilder = ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: para.span.style!.fontFamily,
              fontSize:   para.span.style!.fontSize,
              fontStyle:  para.span.style!.fontStyle,
              fontWeight: para.span.style!.fontWeight,
              textAlign:  TextAlign.justify,
            )
        )
          ..pushStyle(para.span.style!.getTextStyle()) // To use multiple styles, you must make use of the builder and `pushStyle` and then `addText` (or optionally `pop`).
          ..addText(para.span.text!);
        final ui.Paragraph paragraph = paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: size.width - 12.0 - 12.0));
        canvas.drawParagraph(paragraph, Offset(12.0, para.y));
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true; // Just for example, in real environment should be implemented!
  }
}