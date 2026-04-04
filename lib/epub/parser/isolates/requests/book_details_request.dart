import 'dart:isolate';

import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/parser/isolates/responses/opened_response.dart';
import 'package:xml/xml.dart';

import '../../../../models/page_size.dart';
import '../../../../models/page_size_isolate_listener.dart';
import '../../../interfaces/isolate_parse_request.dart';
import '../../../interfaces/isolate_parse_response.dart';
import '../../css_parser.dart';
import '../../epub_parser.dart';
import '../../extensions.dart';
import '../responses/book_details_response.dart';

class ParseCssRequest extends IsolateParseRequest {
  final String css;

  ParseCssRequest({super.id=1, super.href="",, required this.css});

  @override
  void init() {
    // TODO: why is this being called more than once?
    if (!GetIt.instance.isRegistered<CssParser>()) {
      GetIt.instance.registerSingleton<CssParser>(CssParser());
    }
  }

  @override
  Future<IsolateParseResponse> process(SendPort uiPort) async {
    init();

    CssParser cssParser = GetIt.instance.get<CssParser>();
    cssParser.parseCss(css);

    return OpenedResponse(css: cssParser.css);
  }
}