import 'package:flutter/material.dart';

import '../content/text_content.dart';
import 'line_element.dart';

class WordElement extends LineElement {
  final TextContent word;
  double dropCapsAdjust = 0;

  @override
  get element => word;

  @override
  double get ascent => word.ascent;

  WordElement({required this.word, required super.height, required super.width}) {
    // TODO: this is completely fucked. Flutter literally doesn't return the correct width and everything else I have
    // tried: getBoxesForSelection, computeLineMetrics, getOffsetForCaret and even PictureRecorder don't work.
    // So, I have special cased this for now.
    // https://github.com/flutter/flutter/issues/179820
    if (element.elementStyle.textStyle.fontFamily == 'Great Vibes') {
      width = width * 1.5;
    }
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    final TextPainter textPainter = TextPainter(text: word.span, textDirection: TextDirection.ltr,);
    textPainter.layout(maxWidth: width);
    textPainter.paint(c, Offset(xPos, word.isDropCaps ? yPos - dropCapsAdjust: yPos));

    textPainter.dispose();
  }

  @override
  String toString() {
    return '($width/$height/$dropCapsAdjust) ${word.span.style?.fontFamily ?? ""} $word';
  }
}