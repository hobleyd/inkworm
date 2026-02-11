import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import '../models/epub_book.dart';
import '../epub/content/html_content.dart';
import '../epub/parser/epub_isolate.dart';
import '../epub/parser/epub_isolate_deserialization.dart';
import '../epub/parser/epub_parser.dart';
import '../epub/parser/extensions.dart';
import '../epub/structure/epub_chapter.dart';
import '../models/page_size.dart';
import '../models/reading_progress.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  late List<EpubChapter> _chapters;
  late XmlDocument opf;
  Isolate? _chapterIsolate;
  ReceivePort? _chapterReceivePort;
  StreamSubscription? _chapterReceiveSub;
  SendPort? _chapterCommandPort;
  Completer<void>? _chapterReadyCompleter;
  Completer<void>? _chapterBatchCompleter;
  void Function(int index, List<HtmlContent> contents)? _chapterOnChapter;
  VoidCallback? _chapterOnDone;
  String? _defaultCss;
  ReceivePort? _measureReceivePort;
  StreamSubscription? _measureReceiveSub;
  int _parseGeneration = 0;
  int _activeParseGeneration = 0;
  static const int _measureCacheMaxEntries = 1024;
  final Map<String, double> _measureCache = {};
  final Queue<String> _measureCacheOrder = Queue<String>();

  @override
  EpubBook build() {
    return EpubBook(uri: "", author: "", title: "", chapters: [], parsingBook: true);
  }

  void openBook(String book) {
    state = state.copyWith(uri: book);

    final inputStream = InputFileStream(book);
    Archive bookArchive = ZipDecoder().decodeStream(inputStream);
    inputStream.close();

    EpubParser parser = GetIt.instance.get<EpubParser>();
    parser.bookArchive = bookArchive;

    ReadingProgress progress = GetIt.instance.get<ReadingProgress>();
    if (book != progress.book) {
      progress.book          = book;
      progress.chapterNumber = 0;
      progress.pageNumber    = 0;
    }

    PageSize size = GetIt.instance.get<PageSize>();
    if (size.canvasHeight != 0 && size.canvasWidth != 0) {
      parse(progress.chapterNumber);
    } else {
      size.stream.listen((pageSize) {
        parse(progress.chapterNumber);
      });
    }
  }

  /*
   * When parsing the book, parse the current chapter (the first on initial reading) and then one on either side to allow
   * the reader to continue reading while we complete the book parsing.
   */
  void parse(int fromChapterNumber) async {
    try {
      _parseGeneration += 1;
      _activeParseGeneration = _parseGeneration;
      _stopChapterIsolate();
      opf = GetIt.instance.get<EpubParser>().getOPF();

      _chapters = List.generate(opf.spine.length, (int index) => EpubChapter(chapterNumber: index), growable: false);

      // Allow the page to be rendered.
      state = state.copyWith(author: opf.author, title: opf.title, chapters: _chapters, parsingBook: true);

      await _parseInitialChapter(fromChapterNumber, _activeParseGeneration);
      parseRemainingChapters(fromChapterNumber, _activeParseGeneration);
    } catch (e, s) {
      state = state.copyWith(errorDescription: e.toString(), error: s);
    }
  }

  Future<void> parseRemainingChapters(int chapterIndex, int generation) async {
    final chapterOrder = _buildRemainingChapterOrder(chapterIndex);
    final chapterHrefs = opf.spine.map((id) => opf.manifest[id]!.href).toList(growable: false);
    final epubBytes = await File(state.uri).readAsBytes();
    _defaultCss ??= await rootBundle.loadString('assets/default.css');

    await _ensureChapterIsolate(
      chapterHrefs: chapterHrefs,
      epubBytes: epubBytes,
      generation: generation,
    );

    await _sendChapterBatch(
      chapterOrder: chapterOrder,
      generation: generation,
      onChapter: (index, contents) {
        final chapter = EpubChapter(chapterNumber: index);
        chapter.addContent(contents);
        _chapters[index] = chapter;
        state = state.copyWith(chapters: _chapters);
      },
      onDone: () {
        state = state.copyWith(parsingBook: false);
        _stopChapterIsolate();
      },
    );
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }

  List<int> _buildRemainingChapterOrder(int chapterIndex) {
    final order = <int>[];
    if (chapterIndex + 1 < _chapters.length) {
      order.add(chapterIndex + 1);
    }
    if (chapterIndex > 0) {
      order.add(chapterIndex - 1);
    }
    for (int index = 0; index < opf.spine.length; index++) {
      if (!order.contains(index)) {
        order.add(index);
      }
    }
    return order;
  }

  void _stopChapterIsolate() {
    if (_chapterCommandPort != null) {
      _chapterCommandPort!.send({'type': 'stop'});
    }
    _chapterReceiveSub?.cancel();
    _chapterReceiveSub = null;
    _chapterReceivePort?.close();
    _chapterReceivePort = null;
    _chapterIsolate?.kill(priority: Isolate.immediate);
    _chapterIsolate = null;
    _chapterCommandPort = null;
    _chapterReadyCompleter = null;
    _chapterBatchCompleter = null;
    _chapterOnChapter = null;
    _chapterOnDone = null;
    _measureReceiveSub?.cancel();
    _measureReceiveSub = null;
    _measureReceivePort?.close();
    _measureReceivePort = null;
  }

  Future<void> _parseInitialChapter(int chapterIndex, int generation) async {
    final chapterHrefs = opf.spine.map((id) => opf.manifest[id]!.href).toList(growable: false);
    final epubBytes = await File(state.uri).readAsBytes();
    _defaultCss ??= await rootBundle.loadString('assets/default.css');

    await _ensureChapterIsolate(
      chapterHrefs: chapterHrefs,
      epubBytes: epubBytes,
      generation: generation,
    );

    await _sendChapterBatch(
      chapterOrder: [chapterIndex],
      generation: generation,
      onChapter: (index, contents) {
        final chapter = EpubChapter(chapterNumber: index);
        chapter.addContent(contents);
        _chapters[index] = chapter;
        state = state.copyWith(chapters: _chapters);
      },
      onDone: () {},
    );
  }

  Future<void> _ensureChapterIsolate({
    required List<String> chapterHrefs,
    required Uint8List epubBytes,
    required int generation,
  }) async {
    if (generation != _activeParseGeneration) {
      return;
    }

    if (_chapterIsolate != null && _chapterCommandPort != null) {
      return;
    }

    _chapterReadyCompleter = Completer<void>();
    _chapterReceivePort?.close();
    _chapterReceivePort = ReceivePort();
    _chapterReceiveSub = _chapterReceivePort!.listen((message) async {
      try {
        if (generation != _activeParseGeneration) {
          return;
        }
        if (message is! Map) {
          return;
        }
        final type = message['type'];
        if (type == 'ready') {
          _chapterCommandPort = message['commandPort'] as SendPort?;
          if (_chapterReadyCompleter != null && !_chapterReadyCompleter!.isCompleted) {
            _chapterReadyCompleter!.complete();
          }
        } else if (type == 'chapter') {
          final index = message['index'] as int;
          final contents = await contentsFromMapList(message['contents'] as List);
          _chapterOnChapter?.call(index, contents);
        } else if (type == 'done') {
          _chapterOnDone?.call();
          if (_chapterBatchCompleter != null && !_chapterBatchCompleter!.isCompleted) {
            _chapterBatchCompleter!.complete();
          }
        } else if (type == 'error') {
          state = state.copyWith(errorDescription: message['error'] as String?, error: StackTrace.fromString(message['stackTrace'] as String? ?? ''));
          _stopChapterIsolate();
        }
      } catch (e, s) {
        state = state.copyWith(errorDescription: e.toString(), error: s);
        _stopChapterIsolate();
      }
    });

    _ensureMeasurePort();
    PageSize size = GetIt.instance.get<PageSize>();
    ReadingProgress progress = GetIt.instance.get<ReadingProgress>();
    _chapterIsolate = await Isolate.spawn(
      chapterParseIsolateEntry,
      {
        'replyPort': _chapterReceivePort!.sendPort,
        'epubBytes': epubBytes,
        'chapterHrefs': chapterHrefs,
        'defaultCss': _defaultCss,
        'fontSize': progress.fontSize,
        'pixelDensity': size.pixelDensity,
        'measurePort': _measureReceivePort!.sendPort,
      },
    );

    await _chapterReadyCompleter!.future;
  }

  Future<void> _sendChapterBatch({
    required List<int> chapterOrder,
    required int generation,
    required void Function(int index, List<HtmlContent> contents) onChapter,
    required VoidCallback onDone,
  }) async {
    if (generation != _activeParseGeneration) {
      return;
    }
    if (_chapterCommandPort == null) {
      return;
    }

    if (_chapterBatchCompleter != null && !_chapterBatchCompleter!.isCompleted) {
      return;
    }

    _chapterOnChapter = onChapter;
    _chapterOnDone = onDone;
    _chapterBatchCompleter = Completer<void>();

    _chapterCommandPort!.send({
      'type': 'parse',
      'chapterOrder': chapterOrder,
    });

    await _chapterBatchCompleter!.future;
    _chapterOnChapter = null;
    _chapterOnDone = null;
  }

  void _ensureMeasurePort() {
    if (_measureReceivePort != null) {
      return;
    }

    _measureReceivePort = ReceivePort();
    _measureReceiveSub = _measureReceivePort!.listen((message) {
      if (message is! Map) {
        return;
      }
      if (message['type'] != 'measure') {
        return;
      }

      final replyPort = message['replyPort'] as SendPort?;
      if (replyPort == null) {
        return;
      }

      final text = message['text'] as String? ?? "s";
      final fontSize = message['fontSize'] as double?;
      final fontFamily = message['fontFamily'] as String?;
      final fontWeightIndex = message['fontWeight'] as int?;
      final fontStyleIndex = message['fontStyle'] as int?;
      final isHorizontal = message['isHorizontal'] as bool? ?? true;

      final cacheKey = _measureCacheKey(
        text: text,
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontWeightIndex: fontWeightIndex,
        fontStyleIndex: fontStyleIndex,
        isHorizontal: isHorizontal,
      );
      final cached = _measureCache[cacheKey];
      if (cached != null) {
        replyPort.send(cached);
        return;
      }

      final style = TextStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontWeight: fontWeightIndex != null ? FontWeight.values[fontWeightIndex] : null,
        fontStyle: fontStyleIndex != null ? FontStyle.values[fontStyleIndex] : null,
      );

      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      final preferredSize = isHorizontal ? painter.width : painter.height;
      painter.dispose();

      _rememberMeasureCache(cacheKey, preferredSize);
      replyPort.send(preferredSize);
    });
  }

  void _rememberMeasureCache(String key, double value) {
    if (_measureCache.containsKey(key)) {
      _measureCache[key] = value;
      return;
    }

    _measureCache[key] = value;
    _measureCacheOrder.addLast(key);

    while (_measureCacheOrder.length > _measureCacheMaxEntries) {
      final oldest = _measureCacheOrder.removeFirst();
      _measureCache.remove(oldest);
    }
  }

  String _measureCacheKey({
    required String text,
    required double? fontSize,
    required String? fontFamily,
    required int? fontWeightIndex,
    required int? fontStyleIndex,
    required bool isHorizontal,
  }) {
    return [
      text,
      fontSize?.toStringAsFixed(3) ?? 'null',
      fontFamily ?? 'null',
      fontWeightIndex?.toString() ?? 'null',
      fontStyleIndex?.toString() ?? 'null',
      isHorizontal ? 'h' : 'v',
    ].join('|');
  }
}
