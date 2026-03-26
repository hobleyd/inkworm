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

class OpenEpubRequest extends IsolateParseRequest {
  String?   css;
  int?      fontSize;
  int?      initialChapter;
  PageSize? pageSize;
  bool      isolatesReady = false;

  bool get requestComplete => css != null && fontSize != null && initialChapter != null && pageSize != null && isolatesReady;

  OpenEpubRequest({super.id=1, required super.href, this.css, this.fontSize, this.pageSize, this.initialChapter});

  bool update({String? href, String? css, int? fontSize, int? initialChapter, PageSize? pageSize}) {
    this.css            = css            ?? this.css;
    this.fontSize       = fontSize       ?? this.fontSize;
    super.href          = href           ?? this.href;
    this.initialChapter = initialChapter ?? this.initialChapter;
    this.pageSize       = pageSize       ?? this.pageSize;

    return requestComplete;
  }

  @override
  void init() {
    // TODO: why is this being called more than once?
    if (!GetIt.instance.isRegistered<PageSize>()) {
      GetIt.instance.registerSingleton<PageSize>(PageSize());
      GetIt.instance.registerSingleton<CssParser>(CssParser());
      GetIt.instance.registerSingleton<EpubParser>(EpubParser());
      GetIt.instance.registerSingleton<PageSizeIsolateListener>(PageSizeIsolateListener());
    }
  }

  @override
  Future<IsolateParseResponse> process(SendPort uiPort) async {
    init();

    PageSize size = GetIt.instance.get<PageSize>();
    size.update(
        canvasWidth:  pageSize!.canvasWidth,
        canvasHeight: pageSize!.canvasHeight,
        pixelDensity: pageSize!.pixelDensity,
        leftIndent:   pageSize!.leftIndent,
        rightIndent:  pageSize!.rightIndent);

    EpubParser parser = GetIt.instance.get<EpubParser>();
    parser.openBook(href);

    XmlDocument opf = parser.getOPF();
    uiPort.send(BookDetailsResponse(author: opf.author, title: opf.title, length: opf.spine.length));

    CssParser cssParser = GetIt.instance.get<CssParser>();
    cssParser.parseCss(css!);

    return OpenedResponse();
  }
}