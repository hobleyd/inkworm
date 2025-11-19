import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import 'elements/epub_chapter.dart';
import '../models/epub_book.dart';
import 'parser/epub_parser.dart';
import 'parser/extensions.dart';

part 'epub.g.dart';

const platform = MethodChannel('au.com.sharpblue.inkworm/epub');

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  @override
  EpubBook build() {
    if (Platform.isAndroid) {
      _handleAndroidEpubIntent();
    } else if (Platform.isMacOS) {
      _handleMacOSePubIntent();
    } else {
      GetIt.instance.get<EpubParser>().openBook(Platform.environment['EBOOK']!);
    }
    return EpubBook(uri: "", author: "", title: "", chapters: [], manifest: {}, parsingBook: true);
  }

  void parse() async {
    try {
      XmlDocument opf = GetIt.instance.get<EpubParser>().parse();

      List<EpubChapter> chapters = [];
      for (var chapter in opf.spine) {
        debugPrint('parsing: ${opf.manifest[chapter]}');
        chapters.add(await GetIt.instance.get<EpubParser>().parseChapter(opf.spine.indexOf(chapter), opf.manifest[chapter]!.href));
      }
      state = state.copyWith(author: opf.author, title: opf.title, manifest: opf.manifest, chapters: chapters, parsingBook: false);
    } catch (e, s) {
      state = state.copyWith(errorDescription: e.toString(), error: s);
    }
  }


  Future<void> _handleAndroidEpubIntent() async {
    try {
      final Map<dynamic, dynamic> result =
      await platform.invokeMethod('getEpubFile');
      final path = result['path'];
      if (path != null) {
        GetIt.instance.get<EpubParser>().openBook(path);
      } else {
        state = state.copyWith(errorDescription: 'Error receiving file intent: ${result['uri']} / $path');
        GetIt.instance.get<EpubParser>().openBook(Platform.environment['EBOOK']!);
      }
    } catch (e, s) {
      state = state.copyWith(errorDescription: e.toString(), error: s);
    }
  }

  Future<void> _handleMacOSePubIntent() async {
    try {
      final String? path = await platform.invokeMethod('getOpenedFile');
      if (path != null) {
        GetIt.instance.get<EpubParser>().openBook(path);
      }else {
        state = state.copyWith(errorDescription: 'Error receiving file intent: $path');
        GetIt.instance.get<EpubParser>().openBook(Platform.environment['EBOOK']!);
      }
    } catch (e, s) {
      state = state.copyWith(errorDescription: e.toString(), error: s);
    }
  }
}