import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:get_it/get_it.dart';

import '../handlers/block_handler.dart';
import '../handlers/css_handler.dart';
import '../handlers/image_handler.dart';
import '../handlers/inline_handler.dart';
import '../handlers/line_break_handler.dart';
import '../handlers/link_handler.dart';
import '../handlers/superscript_handler.dart';
import '../handlers/text_handler.dart';
import '../../models/page_size.dart';
import '../../models/reading_progress.dart';
import 'css_parser.dart';
import 'epub_isolate_serialization.dart';
import 'epub_parser.dart';
import 'font_management.dart';

const String _kReplyPort = 'replyPort';
const String _kEpubBytes = 'epubBytes';
const String _kChapterHrefs = 'chapterHrefs';
const String _kDefaultCss = 'defaultCss';
const String _kFontSize = 'fontSize';
const String _kPixelDensity = 'pixelDensity';
const String _kMeasurePort = 'measurePort';

const String _kMessageType = 'type';
const String _kMessageTypeChapter = 'chapter';
const String _kMessageTypeDone = 'done';
const String _kMessageTypeError = 'error';
const String _kMessageTypeReady = 'ready';
const String _kMessageTypeParse = 'parse';
const String _kMessageTypeStop = 'stop';

class _IsolateFontManagement extends FontManagement {
  @override
  Future<void> loadFontFromEpub(String fontFamily, String fontPath) async {}
}

@pragma('vm:entry-point')
void chapterParseIsolateEntry(Map<String, Object?> message) async {
  final sendPort = message[_kReplyPort] as SendPort;

  try {
    final epubBytes = message[_kEpubBytes] as Uint8List;
    final chapterHrefs = (message[_kChapterHrefs] as List).cast<String>();
    final defaultCss = message[_kDefaultCss] as String?;
    final fontSize = message[_kFontSize] as int?;
    final pixelDensity = message[_kPixelDensity] as double?;
    final measurePort = message[_kMeasurePort] as SendPort;

    final getIt = GetIt.instance;
    getIt.registerSingleton<PageSize>(PageSize()..update(pixelDensity: pixelDensity ?? 1));
    final progress = ReadingProgress();
    if (fontSize != null) {
      progress.fontSize = fontSize;
    }
    getIt.registerSingleton<ReadingProgress>(progress);
    getIt.registerSingleton<FontManagement>(_IsolateFontManagement());
    getIt.registerSingleton<CssParser>(CssParser(
      defaultCss: defaultCss,
      textMeasureDelegate: IsolateTextMeasureDelegate(measurePort),
    ));

    final parser = EpubParser();
    parser.decodeImages = false;
    parser.bookArchive = ZipDecoder().decodeBytes(epubBytes);
    getIt.registerSingleton<EpubParser>(parser);

    BlockHandler();
    InlineHandler();
    TextHandler();
    LineBreakHandler();
    SuperscriptHandler();
    ImageHandler();
    CssHandler();
    LinkHandler();

    final commandPort = ReceivePort();
    sendPort.send({
      _kMessageType: _kMessageTypeReady,
      'commandPort': commandPort.sendPort,
    });

    await for (final message in commandPort) {
      if (message is! Map) {
        continue;
      }
      final type = message[_kMessageType];
      if (type == _kMessageTypeStop) {
        commandPort.close();
        Isolate.exit();
      }
      if (type != _kMessageTypeParse) {
        continue;
      }

      final List<int> batchOrder = (message['chapterOrder'] as List).cast<int>();
      for (final chapterIndex in batchOrder) {
        final contents = await parser.parseChapterContents(chapterIndex, chapterHrefs[chapterIndex]);
        final serialized = contents.map((content) => contentToDto(content).toJson()).toList(growable: false);
        sendPort.send({
          _kMessageType: _kMessageTypeChapter,
          'index': chapterIndex,
          'contents': serialized,
        });
      }

      sendPort.send({_kMessageType: _kMessageTypeDone});
    }
  } catch (error, stackTrace) {
    sendPort.send({
      _kMessageType: _kMessageTypeError,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
  }
}
