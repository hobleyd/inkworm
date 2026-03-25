// One unit of work handed to a worker isolate.
import 'dart:isolate';

import 'isolate_parse_response.dart';

abstract class IsolateParseRequest {
  const IsolateParseRequest({required this.id, required this.href});

  final int    id;
  final String href;

  void init();

  Future<IsolateParseResponse> process(SendPort uiPort);
}
