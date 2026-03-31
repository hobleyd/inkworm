import 'dart:io';
import 'dart:isolate';

import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/parser/isolates/responses/opened_response.dart';
import 'package:xml/xml.dart';

import '../../interfaces/isolate_listener.dart';
import '../../interfaces/isolate_parse_response.dart';
import '../epub_parser.dart';
import '../extensions.dart';
import 'requests/exit_request.dart';
import 'requests/load_font_request.dart';
import 'requests/measure_image_request.dart';
import 'requests/measure_text_request.dart';
import 'requests/open_epub_request.dart';
import 'requests/parse_chapter_request.dart';
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

  void close() {
    sendToIsolatePort.send(ExitRequest(id: -1, href: ""));
    // TODO: Clear the Image and Text measurements cache.
  }

  void openBook(OpenEpubRequest request) {
    sendToIsolatePort.send(request);
  }

  Future<void> spawn() async {
    final ReceivePort receivePort = ReceivePort();
    receivePort.listen(_onMessageReceived);

    await Isolate.spawn(_startIsolate, receivePort.sendPort);
  }

  static Future<void> _createPool(SendPort uiPort) async {
    for (var i = 0; i < Platform.numberOfProcessors; i++) {
      final WorkerSlot slot = WorkerSlot(uiPort: uiPort);
      await slot.start();
      isolateCores.add(slot);
    }
  }

  // This runs in the UI isolate.
  void _onMessageReceived(dynamic response) {
    switch (response) {
      case SendPort port:
        sendToIsolatePort = port;
        listener.onIsolatesInitialised();
        break;
      case BookDetailsResponse bdr:
        listener.onBookDetails(bdr.author, bdr.title, bdr.length);
        break;
      case ChapterResponse cr:
        listener.onParsedChapter(cr.chapter);
        break;
      case LoadFontRequest lfr:
        lfr.process(sendToIsolatePort);
        break;
      case MeasureImageRequest mir:
        mir.process(sendToIsolatePort);
        break;
      case MeasureTextRequest mtr:
        mtr.process(sendToIsolatePort);
        break;
      default:
        listener.onError(response.error, response.stacktrace);
        break;
    }
  }

  static Future<void> _parseChapter(SendPort port, OpenEpubRequest request, int chapterIndex, String href, Map<String, CssDeclarations> css) async {
    if (isolateCores.isNotEmpty) {
      WorkerSlot slot = isolateCores.removeAt(0);
      IsolateParseResponse response = await slot.process(ParseChapterRequest(id: chapterIndex, href: href, book: request.href, pageSize: request.pageSize!, css: css));
      isolateCores.add(slot);
      port.send(response);
    } else {
      Future.delayed(Duration(milliseconds: 100), () => _parseChapter(port, request, chapterIndex, href, css));
    }
  }

  static void _parseChapters(SendPort port, OpenEpubRequest request, Map<String, CssDeclarations> css) async {
    EpubParser parser = GetIt.instance.get<EpubParser>();
    XmlDocument opf = parser.getOPF();

    final int spineLength = opf.spine.length;
    final Set<int> completedChapters = {};

    _parseChapter(port, request, request.initialChapter!, opf.manifest[opf.spine[request.initialChapter!]]!.href, css);
    completedChapters.add(request.initialChapter!);

    final int nextChapter = request.initialChapter!+1;
    if (nextChapter < spineLength) {
      _parseChapter(port, request, nextChapter, opf.manifest[opf.spine[nextChapter]]!.href, css);
      completedChapters.add(nextChapter);
    }

    if (request.initialChapter! > 0) {
      final int previousChapter = request.initialChapter!-1;
      _parseChapter(port, request, previousChapter, opf.manifest[opf.spine[previousChapter]]!.href, css);
      completedChapters.add(previousChapter);
    }


    for (int chapterIndex = 0; chapterIndex < spineLength; chapterIndex++) {
      if (completedChapters.contains(chapterIndex)) {
        continue;
      }
      _parseChapter(port, request, chapterIndex, opf.manifest[opf.spine[chapterIndex]]!.href, css);
    }
  }

  // This runs within the isolate and cannot communicate directly with the UI.
  static void _startIsolate(SendPort port) {
    final receiveFromUIThreadPort = ReceivePort();
    port.send(receiveFromUIThreadPort.sendPort);

    _createPool(port);

    receiveFromUIThreadPort.listen((dynamic msg) async {
      if (msg is OpenEpubRequest) {
        var response = await msg.process(port);
        // TODO: Pass default CSS to the child isolates; then get the combined CSS back again.
        _parseChapters(port, msg, (response as OpenedResponse).css);
      } else if (msg is ExitRequest) {
        for (var core in isolateCores) {
          core.process(msg);
        }
        msg.process(port);
      }
    });
  }
}
