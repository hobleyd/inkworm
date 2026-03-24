import 'dart:io';
import 'dart:isolate';


import '../../interfaces/isolate_listener.dart';
import '../../interfaces/isolate_parse_request.dart';
import 'requests/open_epub_request.dart';
import 'responses/book_details_response.dart';
import 'responses/chapter_response.dart';
import 'worker_slot.dart';

class IsolateWorker {
  static final List<WorkerSlot> isolateCores = [];

  final IsolateListener listener;
  late SendPort sendToIsolatePort;

  IsolateWorker({required this.listener,})  {
    spawn();
  }

  void openBook(OpenEpubRequest request) {
    sendToIsolatePort.send(request);
  }

  Future<void> spawn() async {
    final ReceivePort receivePort = ReceivePort();
    receivePort.listen(_onMessageReceived);

    await Isolate.spawn(_startIsolate, receivePort.sendPort);
  }

  static Future<void> _createPool() async {
    for (var i = 0; i < Platform.numberOfProcessors; i++) {
      final WorkerSlot slot = WorkerSlot();
      await slot.start();
      isolateCores.add(slot);
    }
  }

  // This runs in the UI isolate.
  void _onMessageReceived(dynamic response) {
    switch (response) {
      case SendPort port:
        sendToIsolatePort = port;
        break;
      case BookDetailsResponse bdr:
        listener.onBookDetails(bdr.author, bdr.title, bdr.length);
        break;
      case ChapterResponse cr:
        listener.onParsedChapter(cr.chapter);
        break;
      default:
          listener.onError(response.error, response.stacktrace);
        break;
    }
  }

  // This runs within the isolate and cannot communicate directly with the UI.
  static void _startIsolate(SendPort port) {
    final receiveFromUIThreadPort = ReceivePort();
    port.send(receiveFromUIThreadPort.sendPort);

    _createPool();

    receiveFromUIThreadPort.listen((dynamic msg) async {
      if (msg is IsolateParseRequest) {
        await msg.process(port);
      }
    });
  }
}
