import 'dart:isolate';

import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/interfaces/isolate_parse_request.dart';
import 'package:inkworm/epub/parser/isolates/responses/chapter_response.dart';

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
import '../../../interfaces/isolate_parse_response.dart';
import '../../../structure/build_line.dart';
import '../../../structure/build_page.dart';
import '../../../structure/epub_chapter.dart';
import '../../css_parser.dart';
import '../../epub_parser.dart';

class ParseChapterRequest extends IsolateParseRequest {
  ParseChapterRequest({required super.id, required super.href});

  bool initComplete = false;

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
      initComplete = true;
    }
    EpubParser parser = GetIt.instance.get<EpubParser>();
    try {
      EpubChapter chapter = await parser.parseChapter(id, href);
      uiPort.send(ChapterResponse(chapter: chapter));
    } catch (e, s) {
      uiPort.send(IsolateParseResponse(error: e.toString(), stacktrace: s.toString()));
    }
  }

}