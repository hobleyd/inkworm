import 'dart:isolate';

import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/parser/isolates/responses/opened_response.dart';
import 'package:xml/xml.dart';

import '../../../../models/page_size.dart';
import '../../../interfaces/isolate_parse_request.dart';
import '../../../interfaces/isolate_parse_response.dart';
import '../../css_parser.dart';
import '../../epub_parser.dart';
import '../../extensions.dart';
import '../responses/book_details_response.dart';

class OpenEpubRequest extends IsolateParseRequest {
  final String   css;
  final double   fontSize;
  final PageSize pageSize;
  final int      initialChapter;

  bool initComplete = false;

  OpenEpubRequest({super.id=1, required super.href, required this.css, required this.fontSize, required this.pageSize, required this.initialChapter});

  @override
  void init() {
    GetIt.instance.registerSingleton<PageSize>(PageSize());
    GetIt.instance.registerSingleton<CssParser>(CssParser());
    GetIt.instance.registerSingleton<EpubParser>(EpubParser());
  }

  @override
  Future<IsolateParseResponse> process(SendPort uiPort) async {
    if (!initComplete) {
      init();
    }

    PageSize size = GetIt.instance.get<PageSize>();
    size.update(
        canvasWidth:  pageSize.canvasWidth,
        canvasHeight: pageSize.canvasHeight,
        pixelDensity: pageSize.pixelDensity,
        leftIndent:   pageSize.leftIndent,
        rightIndent:  pageSize.rightIndent);

    EpubParser parser = GetIt.instance.get<EpubParser>();
    parser.openBook(href);

    XmlDocument opf = parser.getOPF();
    uiPort.send(BookDetailsResponse(author: opf.author, title: opf.title, length: opf.spine.length));

    CssParser cssParser = GetIt.instance.get<CssParser>();
    cssParser.parseCss(css);

    return OpenedResponse();
  }
}