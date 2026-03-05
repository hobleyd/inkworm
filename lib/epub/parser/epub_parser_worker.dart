import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart' hide ImageCache;
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/models/element_size.dart';
import 'package:xml/xml.dart';

import '../../models/page_size.dart';
import '../../models/page_size_isolate_listener.dart';
import '../cache/link_cache.dart';
import '../cache/text_cache.dart';
import '../content/text_content.dart';
import '../handlers/block_handler.dart';
import '../handlers/css_handler.dart';
import '../handlers/image_handler.dart';
import '../handlers/inline_handler.dart';
import '../handlers/line_break_handler.dart';
import '../handlers/link_handler.dart';
import '../handlers/superscript_handler.dart';
import '../handlers/text_handler.dart';
import '../interfaces/isolate_listener.dart';
import '../structure/build_line.dart';
import '../structure/build_page.dart';
import '../structure/epub_chapter.dart';
import '../cache/image_cache.dart';
import '../styles/element_style.dart';
import 'css_parser.dart';
import 'epub_parser.dart';
import 'extensions.dart';

const String _bookDetails = 'details';
const String _defaultCss  = 'css';
const String _chapter     = 'chapter';
const String _close       = 'close';
const String _exception   = 'error';
const String _fontSize    = 'fontSize';
const String _imagePaint  = 'image';
const String _openBook    = 'open';
const String _pageSize    = 'pageSize';
const String _port        = 'port';
const String _textPaint   = 'paint';

class EpubParserWorker {
  final IsolateListener isolateListener;

  late SendPort _sendPort;
  static SendPort? isolateSendPort;

  EpubParserWorker({ required this.isolateListener }) {
    spawn();
  }

  void getBookDetails() {
    _sendPort.send({
      'type': _bookDetails
    });
  }

  static Future<ElementSize> measureImageInMainThread(String name, Uint8List imageBytes) async {
    // TODO: While the ui.Image is cached in the main isolate, we should also cache on this side to save the
    // imageBytes being processed multiple times.
    final reply = ReceivePort();
    EpubParserWorker.isolateSendPort?.send({
      'type':      _imagePaint,
      'name':      name,
      'bytes':     imageBytes,
      'replyPort': reply.sendPort,
    });
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
    EpubParserWorker.isolateSendPort?.send({
      'type':       _textPaint,
      'text':       text,
      'fontSize':   style.fontSize,
      'fontFamily': style.fontFamily,
      'fontWeight': style.fontWeight?.index,
      'fontStyle':  style.fontStyle?.index,
      'replyPort':  reply.sendPort,
    });
    ElementSize result = await reply.first;
    cache.addCacheElement(text, style, result);
    reply.close();
    return result;
  }

  void close() {
    _sendPort.send({
      'type': _close,
    });
  }

  void openBook(String book) {
    _sendPort.send({
      'type': _openBook,
      'book': book
    });
  }

  void parseChapters(int initialIndex, int spineLength) {
    _sendPort.send({
      'type': _chapter,
      'initial': initialIndex,
      'length': spineLength,
    });
  }

  Future<void> parseDefaultCss() async {
    String css = await rootBundle.loadString('assets/default.css');
    _sendPort.send({
      'type': _defaultCss,
      'css': css,
    });
  }

  void setFontSize(int fontSize) {
    _sendPort.send({
      'type': _fontSize,
      'fontSize': fontSize,
    });
  }

  void setPageSize(PageSize size) {
    _sendPort.send({
      'type': _pageSize,
      'size': size
    });
  }

  Future<void> spawn() async {
    final ReceivePort receivePort = ReceivePort();
    receivePort.listen(_handleChapter);

    await Isolate.spawn(_startIsolate, receivePort.sendPort);
  }

  void _handleChapter(dynamic message) {
    if (message is Map) {
      switch (message['type']) {
        case _bookDetails:
          isolateListener.onBookDetails(message['author'], message['title'], message['length']);
          break;
        case _chapter:
          isolateListener.onParsedChapter(message['chapter']);
          isolateListener.onComplete();
          break;
        case _exception:
          isolateListener.onError(message['error'], message['trace']);
          break;
        case _imagePaint:
          _measureImage(message['name'], message['bytes'], message['replyPort']);
          break;
        case _pageSize:
          isolateListener.onSizeReceived();
        case _port:
          _sendPort = message['port'];
          isolateListener.onInitialised(true);
          break;
        case _textPaint:
          TextStyle style = TextStyle(
              fontSize: message['fontSize'],
              fontFamily: message['fontFamily'],
              fontWeight: message['fontWeight'] != null ? FontWeight.values[message['fontWeight']] : FontWeight.w400,
              fontStyle: message['fontStyle']
          );

          TextPainter paint = TextPainter(textDirection: TextDirection.ltr, text: TextSpan(text: message['text'], style: style));
          PageSize size = GetIt.instance.get<PageSize>();
          paint.layout(maxWidth: size.canvasWidth - size.leftIndent - size.rightIndent);
          message['replyPort'].send(ElementSize(height: paint.height, width: paint.width));
          paint.dispose();
          break;
      }
    }
  }

  static void _startIsolate(SendPort port) {
    isolateSendPort = port;

    GetIt.instance.registerSingleton<PageSize>(PageSize());
    GetIt.instance.registerSingleton<CssParser>(CssParser());
    GetIt.instance.registerSingleton<EpubParser>(EpubParser());
    GetIt.instance.registerSingleton<BlockHandler>(BlockHandler());
    GetIt.instance.registerSingleton<TextHandler>(TextHandler());
    GetIt.instance.registerSingleton<LineBreakHandler>(LineBreakHandler());
    GetIt.instance.registerSingleton<InlineHandler>(InlineHandler());
    GetIt.instance.registerSingleton<LinkHandler>(LinkHandler());
    GetIt.instance.registerSingleton<ImageHandler>(ImageHandler());
    GetIt.instance.registerSingleton<SuperscriptHandler>(SuperscriptHandler());
    GetIt.instance.registerSingleton<CssHandler>(CssHandler());
    GetIt.instance.registerSingleton<BuildLine>(BuildLine());
    GetIt.instance.registerSingleton<BuildPage>(BuildPage());
    GetIt.instance.registerSingleton<LinkCache>(LinkCache());
    GetIt.instance.registerSingleton<PageSizeIsolateListener>(PageSizeIsolateListener());
    GetIt.instance.registerSingleton<TextCache>(TextCache());

    final ReceivePort receivePort = ReceivePort();
    port.send({'type': _port, 'port': receivePort.sendPort});

    receivePort.listen((dynamic message) async {
      if (message is Map) {
        EpubParser parser = GetIt.instance.get<EpubParser>();
        switch (message['type']) {
          case _bookDetails:
            XmlDocument opf = parser.getOPF();
            port.send({
              'type': _bookDetails,
              'author': opf.author,
              'title': opf.title,
              'length': opf.spine.length
            });
            break;
          case _chapter:
            _parseChapters(port, message['initial'], message['length']);
            break;
          case _close:
            Isolate.exit();
          case _defaultCss:
            CssParser cssParser = GetIt.instance.get<CssParser>();
            cssParser.parseCss(message['css']);
            break;
          case _fontSize:
            ElementStyle.defaultFontSize = message['fontSize'];
            break;
          case _openBook:
            parser.openBook(message['book']);
            break;
          case _pageSize:
            PageSize size = GetIt.instance.get<PageSize>();
            PageSize received = message['size'];
            size.update(
              pixelDensity: received.pixelDensity,
              canvasHeight: received.canvasHeight,
              canvasWidth:  received.canvasWidth,
              leftIndent:   received.leftIndent,
              rightIndent:  received.rightIndent,
            );
            port.send({'type': _pageSize});
            break;
        }
      }
    });
  }

  Future<void> _measureImage(String name, Uint8List bytes, SendPort port) async {
    ImageCache cache = GetIt.instance.get<ImageCache>();

    if (!cache.isCached(name)) {
      await cache.addImage(name, bytes);
    }
    port.send(ElementSize(width: cache[name].width.toDouble(), height: cache[name].height.toDouble()));
  }

  static Future<void> _parseChapter(SendPort port, int chapterIndex, String href) async {
    EpubParser parser = GetIt.instance.get<EpubParser>();
    try {
      EpubChapter chapter = await parser.parseChapter(chapterIndex, href);
      port.send({
        'type':    _chapter,
        'chapter': chapter
      });
    } catch (e, s) {
      port.send({
        'type': _exception,
        'error': e.toString(),
        'trace': s.toString(),
      });
    }
  }

  /*
   * When parsing the book, parse the current chapter (the first on initial reading) and then one on either side to allow
   * the reader to continue reading while we complete the book parsing.
   */
  static void _parseChapters(SendPort port, int initialIndex, int spineLength) async {
    EpubParser parser = GetIt.instance.get<EpubParser>();
    XmlDocument opf = parser.getOPF();
    Set<int> completedChapters = {};

    await _parseChapter(port, initialIndex, opf.manifest[opf.spine[initialIndex]]!.href);
    completedChapters.add(initialIndex);

    final int nextChapter = initialIndex+1;
    if (nextChapter < spineLength) {
      await _parseChapter(port, nextChapter, opf.manifest[opf.spine[nextChapter]]!.href);
      completedChapters.add(nextChapter);
    }

    if (initialIndex > 0) {
      final int previousChapter = initialIndex-1;
      await _parseChapter(port, previousChapter, opf.manifest[opf.spine[previousChapter]]!.href);
      completedChapters.add(previousChapter);
    }


    for (int chapterIndex = 0; chapterIndex < spineLength; chapterIndex++) {
      if (completedChapters.contains(chapterIndex)) {
        continue;
      }
      await _parseChapter(port, chapterIndex, opf.manifest[opf.spine[chapterIndex]]!.href);
    }
  }
}
