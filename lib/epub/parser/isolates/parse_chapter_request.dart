import 'package:inkworm/epub/parser/isolates/isolate_parse_request.dart';

import 'isolate_parse_response.dart';

class ParseChapterRequest extends IsolateParseRequest {
  ParseChapterRequest({required super.id, required super.href});

  @override
  Future<IsolateParseResponse> process() {
    // TODO: implement process
    throw UnimplementedError();
  }

}