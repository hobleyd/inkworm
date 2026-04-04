// One unit of work handed to a worker isolate.
import 'dart:isolate';

import 'isolate_parse_response.dart';

abstract class IsolateParseRequest {
  IsolateParseRequest({required this.href});

  String href;

  void init();

  Future<IsolateParseResponse> process(SendPort uiPort);
}
