import 'package:flutter/material.dart';
import 'package:inkworm/epub/parser/epub_parser_worker.dart';

import '../content/html_content.dart';
import '../content/text_content.dart';

abstract class LineElement {
  late double height;
  late double width;

  // TODO
  // Link _link;

  HtmlContent get element;
  bool        get isDropCaps => element.elementStyle.isDropCaps ?? false;

  LineElement();

  Future<bool> getConstraints() async {
    debugPrint('getConstraints($element)');
    Map<String, double> size = await EpubParserWorker.measureTextInMainThread((element as TextContent).text, (element as TextContent).span.style!);
    width = size['width']!;
    height = size['height']!;
    debugPrint('getConstraints($element) $width/$height');

    // TODO: this is completely fucked. Flutter literally doesn't return the correct width and everything else I have
    // tried: getBoxesForSelection, computeLineMetrics, getOffsetForCaret and even PictureRecorder don't work.
    // So, I have special cased this for now and will have to investigate further.
    if (element.elementStyle.textStyle.fontFamily == 'Great Vibes') {
      width = width * 1.5;
    }

    return true;
  }

  void paint(Canvas c, double height, double xPos, double yPos);

  @override
  String toString() {
    return '$element';
  }
}