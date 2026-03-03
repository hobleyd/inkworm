import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/parser/epub_parser_worker.dart';

import '../cache/measure_cache.dart';
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
    MeasureCache cache = GetIt.instance.get<MeasureCache>();
    if (!cache.contains(element)) {
      Map<String, double> size = await EpubParserWorker.measureTextInMainThread((element as TextContent).text, (element as TextContent).span.style!);
      width = size['width']!;
      height = size['height']!;
      debugPrint('got constraints($element) $width/$height');
      cache.addCacheElement(element, width: width, height: height);
    }
    else {
      ElementSize size = cache[element]!;
      width = size.width;
      height = size.height;
      debugPrint('cached constraints($element) $width/$height');
    }
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