import 'dart:isolate';

import '../../interfaces/isolate_parse_request.dart';
import '../../interfaces/isolate_parse_response.dart';
import 'worker_message.dart';

class WorkerSlot {
  late Isolate _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;

  /// Spawns the isolate and waits for it to report its [SendPort].
  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort.sendPort,);
    _sendPort = await _receivePort.first as SendPort;
  }

  /// Sends one [IsolateParseRequest] and waits for the [IsolateParseResponse].
  Future<IsolateParseResponse> process(IsolateParseRequest request) async {
    final replyPort = ReceivePort();
    _sendPort.send(WorkerMessage(request: request, replyPort: replyPort.sendPort),);
    final result = await replyPort.first as IsolateParseResponse;
    replyPort.close();
    return result;
  }

  // Terminates the isolate and cleans up ports.
  Future<void> stop() async {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }

  static void _isolateEntryPoint(SendPort parentPort) {
    final inbox = ReceivePort();
    parentPort.send(inbox.sendPort);

    inbox.listen((dynamic msg) async {
      if (msg is WorkerMessage) {
        final result = await msg.request.process(parentPort);
        msg.replyPort.send(result);
      }
    });
  }

}