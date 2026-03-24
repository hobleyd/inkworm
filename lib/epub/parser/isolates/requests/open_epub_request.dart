import 'dart:isolate';

import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/interfaces/isolate_parse_request.dart';
import 'package:inkworm/epub/parser/isolates/responses/book_details_response.dart';
import 'package:xml/xml.dart';

import '../../../../models/page_size.dart';
import '../../../cache/link_cache.dart';
import '../../../cache/text_cache.dart';
import '../../../handlers/block_handler.dart';
import '../../../handlers/css_handler.dart';
import '../../../handlers/image_handler.dart';
import '../../../handlers/inline_handler.dart';
import '../../../handlers/line_break_handler.dart';
import '../../../handlers/link_handler.dart';
import '../../../handlers/superscript_handler.dart';
import '../../../handlers/text_handler.dart';
import '../../../structure/build_line.dart';
import '../../../structure/build_page.dart';
import '../../css_parser.dart';
import '../../epub_parser.dart';
import '../../extensions.dart';

class OpenEpubRequest extends IsolateParseRequest {
  final String   css;
  final double   fontSize;
  final PageSize pageSize;

  bool initComplete = false;

  OpenEpubRequest({super.id=1, required super.href, required this.css, required this.fontSize, required this.pageSize});

  @override
  void init() {
    GetIt.instance.registerSingleton<PageSize>(PageSize());
    GetIt.instance.registerSingleton<CssParser>(CssParser());
    GetIt.instance.registerSingleton<EpubParser>(EpubParser());
    GetIt.instance.registerSingleton<BlockHandler>(BlockHandler());
    GetIt.instance.registerSingleton<TextHandler>(TextHandler());
    GetIt.instance.registerSingleton<LineBreakHandler>(LineBreakHandler());
    GetIt.instance.registerSingleton<InlineHandler>(InlineHandler());
    GetIt.instance.registerSingleton<LinkHandler>(LinkHandler());
    GetIt.instance.registerSingleton<ImageHandler>(ImageHandler());
    GetIt.instance.registerSingleton<SuperscriptHandler>(SuperscriptHandler());
    GetIt.instance.registerSingleton<CssHandler>(CssHandler());
    GetIt.instance.registerSingleton<BuildLine>(BuildLine());
    GetIt.instance.registerSingleton<BuildPage>(BuildPage());
    GetIt.instance.registerSingleton<LinkCache>(LinkCache());
    GetIt.instance.registerSingleton<TextCache>(TextCache());
  }

  @override
  Future<void> process(SendPort uiPort) async {
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
  }
}