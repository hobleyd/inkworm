import 'dart:isolate';

import 'package:inkworm/epub/interfaces/isolate_parse_request.dart';

import '../../../interfaces/isolate_parse_response.dart';

class ParseChapterRequest extends IsolateParseRequest {
  ParseChapterRequest({required super.id, required super.href});

  @override
  void init() {

  }

  @override
  Future<IsolateParseResponse> process(SendPort uiPort) {
    // TODO: implement process
    throw UnimplementedError();
  }

}