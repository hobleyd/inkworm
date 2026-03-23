import 'package:inkworm/epub/parser/isolates/isolate_parse_request.dart';

import 'isolate_parse_response.dart';

class OpenEpubRequest extends IsolateParseRequest{
  OpenEpubRequest({required super.id, required super.href});

  @override
  Future<IsolateParseResponse> process() async {
    // TODO: implement process
    throw UnimplementedError();
  }
}