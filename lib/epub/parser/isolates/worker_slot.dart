import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/parser/isolates/requests/load_font_request.dart';

import '../../../models/element_size.dart';
import '../../cache/text_cache.dart';
import '../../interfaces/isolate_parse_request.dart';
import '../../interfaces/isolate_parse_response.dart';
import 'requests/measure_image_request.dart';
import 'requests/measure_text_request.dart';
import 'worker_message.dart';

class WorkerSlot {
  late Isolate _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;

  final SendPort uiPort;
  static SendPort? staticUIPort;

  WorkerSlot({required this.uiPort});

  static void loadFont(String fontFamily, String fontPath) {
    staticUIPort?.send(LoadFontRequest(fontFamily: fontFamily, href: fontPath,));
  }

  static Future<ElementSize> measureImageInMainThread(String name, Uint8List imageBytes) async {
    // TODO: While the ui.Image is cached in the main isolate, we should also cache on this side to save the
    // imageBytes being processed multiple times.
    final reply = ReceivePort();
    staticUIPort?.send(MeasureImageRequest(href: name, imageBytes: imageBytes, port: reply.sendPort));

    ElementSize result = await reply.first;
    reply.close();
    return result;
  }

  static Future<ElementSize> measureTextInMainThread(String text, TextStyle style) async {
    // This is only cached in the parsing isolate and should be disposed once parsing is complete.
    final TextCache cache = GetIt.instance.get<TextCache>();
    if (cache.contains(text, style)) {
      return cache.get(text, style)!;
    }

    final reply = ReceivePort();
    staticUIPort?.send(MeasureTextRequest(href: text, style: style, port: reply.sendPort));

    ElementSize result = await reply.first;
    cache.addCacheElement(text, style, result);
    reply.close();
    return result;
  }

  /// Spawns the isolate and waits for it to report its [SendPort].
  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort.sendPort,);
    _sendPort = await _receivePort.first as SendPort;
  }

  /// Sends one [IsolateParseRequest] and waits for the [IsolateParseResponse].
  Future<IsolateParseResponse> process(IsolateParseRequest request) async {
    final replyPort = ReceivePort();
    _sendPort.send(WorkerMessage(request: request, replyPort: replyPort.sendPort, uiPort: uiPort),);
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
        staticUIPort = msg.uiPort;
        final result = await msg.request.process(parentPort);
        msg.replyPort.send(result);
      }
    });
  }
}