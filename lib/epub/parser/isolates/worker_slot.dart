import 'dart:isolate';

import '../../interfaces/isolate_parse_request.dart';
import '../../interfaces/isolate_parse_response.dart';
import 'worker_message.dart';

class WorkerSlot {
  late Isolate _isolate;
  late SendPort _sendPort;

  /// Spawns the isolate and waits for it to report its [SendPort].
  Future<void> start() async {
    _receivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort.sendPort,);

    // First message back is the isolate's own SendPort.
    _sendPort = await _receivePort.first as SendPort;
  }

  /// Terminates the isolate and cleans up ports.
  Future<void> stop() async {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}

/// Top-level function required by [Isolate.spawn].
void _isolateEntryPoint(SendPort parentPort) {
  final inbox = ReceivePort();
  parentPort.send(inbox.sendPort);

  inbox.listen((dynamic msg) async {
    if (msg is WorkerMessage) {
      final result = await _process(msg.request);
      msg.replyPort.send(result);
    }
  });
}

// Runs inside the worker isolate. Must be a top-level (or static) function.
Future<IsolateParseResponse> _process(IsolateParseRequest req) async {
  try {
    return req.process();
  } catch (e, st) {
    return IsolateParseResponse(id: req.id, error: '$e\n$st');
  }
}

