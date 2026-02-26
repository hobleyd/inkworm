import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide ImageCache;
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../../models/page_size.dart';
import '../handlers/block_handler.dart';
import '../handlers/css_handler.dart';
import '../handlers/image_handler.dart';
import '../handlers/inline_handler.dart';
import '../handlers/line_break_handler.dart';
import '../handlers/link_handler.dart';
import '../handlers/superscript_handler.dart';
import '../handlers/text_handler.dart';
import '../structure/build_line.dart';
import '../structure/build_page.dart';
import '../structure/epub_chapter.dart';
import '../structure/image_cache.dart';
import '../styles/element_style.dart';
import 'css_parser.dart';
import 'epub_parser.dart';
import 'extensions.dart';

const String _bookDetails = 'details';
const String _defaultCss  = 'css';
const String _chapter     = 'chapter';
const String _exception   = 'error';
const String _fontSize    = 'fontsize';
const String _imagePaint  = 'image';
const String _openBook    = 'open';
const String _pageSize    = 'size';
const String _textPaint   = 'paint';

class EpubParserWorker {
  final void Function(String author, String title, int spineLength) onBookDetails;
  final void Function() onComplete;
  final void Function(String error, String stackTrace, ) onError;
  final void Function(int index, EpubChapter chapter) onParsedChapter;

  late SendPort _sendPort;
  static SendPort? isolateSendPort;

  final Completer<void> _isolateReady = Completer.sync();

  EpubParserWorker({ required this.onBookDetails, required this.onComplete, required this.onError, required this.onParsedChapter}) {
    spawn();
  }

  void getBookDetails() {
    _sendPort.send({
      'type': _bookDetails
    });
  }

  static Future<Map<String, double>> measureImageInMainThread(String name, Uint8List imageBytes) async {
    final reply = ReceivePort();
    EpubParserWorker.isolateSendPort?.send({
      'type':      _imagePaint,
      'name':      name,
      'bytes':     imageBytes,
      'replyPort': reply.sendPort,
    });
    Map<String, double> result = await reply.first;
    reply.close();
    return result;
  }

  static Future<Map<String, double>> measureTextInMainThread(String text, TextStyle style) async {
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
    Map<String, double> result = await reply.first;
    reply.close();
    return result;
  }

  void openBook(String book) {
    _sendPort.send({
      'type': _openBook,
      'book': book
    });
  }

  void parseChapter(int chapterIndex) {
    _sendPort.send(chapterIndex);
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
    _sendPort.send(size);
  }

  Future<void> spawn() async {
    final ReceivePort receivePort = ReceivePort();
    receivePort.listen(_handleChapter);

    await Isolate.spawn(_startIsolate, receivePort.sendPort);
  }

  void _handleChapter(dynamic message) {
    debugPrint('message: $message');
    if (message is SendPort) {
      _sendPort = message;
    }
    if (message is Map) {
      switch (message['type']) {
        case _bookDetails:
          onBookDetails(message['author'], message['title'], message['length']);
          break;
        case _chapter:
          onParsedChapter(message['index'], message['chapter']);
          onComplete();
          break;
        case _exception:
          onError(message['error'], message['trace']);
          break;
        case _imagePaint:
          _measureImage(message['name'], message['bytes'], message['replyPort']);
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
          message['replyPort'].send({
            'width': paint.width,
            'height': paint.height
          });
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

    final ReceivePort receivePort = ReceivePort();
    port.send(receivePort.sendPort);

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
        }
      } else if (message is PageSize) {
        PageSize size = GetIt.instance.get<PageSize>();
        size.update(
            pixelDensity: message.pixelDensity,
            canvasHeight: message.canvasHeight,
            canvasWidth: message.canvasWidth,
            leftIndent: message.leftIndent,
            rightIndent: message.rightIndent,
        );
      } else if (message is int) {
        EpubParser parser = GetIt.instance.get<EpubParser>();
        XmlDocument opf = parser.getOPF();
        try {
          EpubChapter chapter = await parser.parseChapter(message, opf.manifest[opf.spine[message]]!.href);
          port.send({
            'type': _chapter,
            'index': message,
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
    });
  }

  Future<void> _measureImage(String name, Uint8List bytes, SendPort port) async {
    ImageCache cache = GetIt.instance.get<ImageCache>();

    if (!cache.isCached(name)) {
      await cache.addImage(name, bytes);
    }
    port.send({
      'width': cache[name].width.toDouble(),
      'height': cache[name].height.toDouble()
    });
  }
}
