import 'dart:isolate';

import 'package:get_it/get_it.dart';

import '../../../../models/page_size.dart';
import '../../../../models/page_size_isolate_listener.dart';
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
import '../../../interfaces/isolate_parse_request.dart';
import '../../../interfaces/isolate_parse_response.dart';
import '../../../structure/build_line.dart';
import '../../../structure/build_page.dart';
import '../../../structure/epub_chapter.dart';
import '../../css_parser.dart';
import '../../epub_parser.dart';
import '../responses/chapter_response.dart';

class ParseChapterRequest extends IsolateParseRequest {
  final String book;
  final PageSize pageSize;

  ParseChapterRequest({required super.id, required super.href, required this.book, required this.pageSize});

  bool initComplete = false;

  @override
  void init() {
    // TODO: The try loop is here, because this gets called twice, and I am not sure why. Look into this.
    try {
      GetIt.instance.registerSingleton<PageSize>(PageSize());
      GetIt.instance.registerSingleton<PageSizeIsolateListener>(PageSizeIsolateListener());
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
    } catch (e) {}

    initComplete = true;
  }

  @override
  Future<IsolateParseResponse> process(SendPort uiPort) async {
    if (!initComplete) {
      init();
    }
    EpubParser parser = GetIt.instance.get<EpubParser>();
    try {
      parser.openBook(book);
      PageSize size = GetIt.instance.get<PageSize>();
      size.update(
          canvasHeight: pageSize.canvasHeight,
          canvasWidth: pageSize.canvasWidth,
          pixelDensity: pageSize.pixelDensity,
          leftIndent: pageSize.leftIndent,
          rightIndent: pageSize.rightIndent);
      final EpubChapter chapter = await parser.parseChapter(id, href);
      final ChapterResponse response = ChapterResponse(chapter: chapter);
      //uiPort.send(response);
      return response;
    } catch (e, s) {
      IsolateParseResponse response = IsolateParseResponse(error: e.toString(), stacktrace: s.toString());
      //uiPort.send(response);
      return response;
    }
  }
}