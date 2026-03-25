import 'dart:io';
import 'dart:isolate';


import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/interfaces/isolate_parse_response.dart';
import 'package:inkworm/epub/parser/isolates/requests/parse_chapter_request.dart';
import 'package:xml/xml.dart';

import '../../interfaces/isolate_listener.dart';
import '../../interfaces/isolate_parse_request.dart';
import '../epub_parser.dart';
import '../extensions.dart';
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

  static Future<void> _parseChapter(SendPort port, int chapterIndex, String href) async {
    if (isolateCores.isNotEmpty) {
      WorkerSlot slot = isolateCores.removeAt(0);
      IsolateParseResponse response = await slot.process(ParseChapterRequest(id: chapterIndex, href: href));
      isolateCores.add(slot);
      port.send(response);
    } else {
      Future.delayed(Duration(milliseconds: 100), () => _parseChapter(port, chapterIndex, href));
    }

  }

  static void _parseChapters(SendPort port, int initialIndex) async {
    EpubParser parser = GetIt.instance.get<EpubParser>();
    XmlDocument opf = parser.getOPF();

    final int spineLength = opf.spine.length;
    final Set<int> completedChapters = {};

    _parseChapter(port, initialIndex, opf.manifest[opf.spine[initialIndex]]!.href);
    completedChapters.add(initialIndex);

    final int nextChapter = initialIndex+1;
    if (nextChapter < spineLength) {
      _parseChapter(port, nextChapter, opf.manifest[opf.spine[nextChapter]]!.href);
      completedChapters.add(nextChapter);
    }

    if (initialIndex > 0) {
      final int previousChapter = initialIndex-1;
      _parseChapter(port, previousChapter, opf.manifest[opf.spine[previousChapter]]!.href);
      completedChapters.add(previousChapter);
    }


    for (int chapterIndex = 0; chapterIndex < spineLength; chapterIndex++) {
      if (completedChapters.contains(chapterIndex)) {
        continue;
      }
      _parseChapter(port, chapterIndex, opf.manifest[opf.spine[chapterIndex]]!.href);
    }
  }

  // This runs within the isolate and cannot communicate directly with the UI.
  static void _startIsolate(SendPort port) {
    final receiveFromUIThreadPort = ReceivePort();
    port.send(receiveFromUIThreadPort.sendPort);

    _createPool();

    receiveFromUIThreadPort.listen((dynamic msg) async {
      if (msg is OpenEpubRequest) {
        await msg.process(port);

        _parseChapters(port, msg.initialChapter);
      }
    });
  }
}
