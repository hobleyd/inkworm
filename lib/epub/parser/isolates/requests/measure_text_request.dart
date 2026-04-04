import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/interfaces/isolate_parse_request.dart';

import '../../../../models/element_size.dart';
import '../../../../models/page_size.dart';
import '../../../interfaces/isolate_parse_response.dart';

class MeasureTextRequest extends IsolateParseRequest {
  final TextStyle style;
  final SendPort port;

  // TODO: remove id and href from the abstract super class?
  MeasureTextRequest({required super.href, required this.style, required this.port});

  @override
  void init() {}

  @override
  Future<IsolateParseResponse> process(_) async {
    PageSize size = GetIt.instance.get<PageSize>();

    TextPainter paint = TextPainter(textDirection: TextDirection.ltr, text: TextSpan(text: href, style: style));
    paint.layout(maxWidth: size.canvasWidth - size.leftIndent - size.rightIndent);
    LineMetrics lm = paint.computeLineMetrics().first;

    port.send(ElementSize(ascent: lm.ascent, descent: lm.descent, height: paint.height, width: paint.width));

    paint.dispose();

    // Not used; just for the interface definition.
    return IsolateParseResponse();
  }
}