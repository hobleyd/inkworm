import 'dart:isolate';

import '../../interfaces/isolate_parse_request.dart';

class WorkerMessage {
  final IsolateParseRequest request;
  final SendPort replyPort;

  const WorkerMessage({required this.request, required this.replyPort});
}