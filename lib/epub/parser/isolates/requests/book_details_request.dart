import 'dart:isolate';

import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../../../interfaces/isolate_parse_request.dart';
import '../../../interfaces/isolate_parse_response.dart';
import '../../epub_parser.dart';
import '../../extensions.dart';
import '../responses/book_details_response.dart';

class BookDetailsRequest extends IsolateParseRequest {
  BookDetailsRequest({required super.href,});

  @override
  void init() {
    if (!GetIt.instance.isRegistered<EpubParser>()) {
      GetIt.instance.registerSingleton<EpubParser>(EpubParser());
    }
  }

  @override
  Future<IsolateParseResponse> process(SendPort uiPort) async {
    init();

    EpubParser parser = GetIt.instance.get<EpubParser>();
    parser.openBook(href);

    XmlDocument opf = parser.getOPF();
    uiPort.send(BookDetailsResponse(author: opf.author, title: opf.title, length: opf.spine.length));

    return IsolateParseResponse();
  }
}