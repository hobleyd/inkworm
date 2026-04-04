import 'dart:isolate';

import 'package:inkworm/epub/interfaces/isolate_parse_request.dart';

import '../../../interfaces/isolate_parse_response.dart';

class ExitRequest extends IsolateParseRequest{
  ExitRequest({required super.href});

  @override
  void init() {}

  @override
  Future<IsolateParseResponse> process(SendPort uiPort) async {
    Isolate.exit();
  }
}