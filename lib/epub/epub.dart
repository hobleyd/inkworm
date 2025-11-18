import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import 'elements/epub_chapter.dart';
import '../models/epub_book.dart';
import 'parser/epub_parser.dart';
import 'parser/extensions.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  @override
  EpubBook build() {
    return EpubBook(author: "", title: "", chapters: [], manifest: {}, parsingBook: true);
  }

  void parse() async {
    try {
      GetIt.instance.get<EpubParser>().openBook();
      XmlDocument opf = GetIt.instance.get<EpubParser>().parse();

      List<EpubChapter> chapters = [];
      for (var chapter in opf.spine) {
        debugPrint('parsing: ${opf.manifest[chapter]}');
        chapters.add(await GetIt.instance.get<EpubParser>().parseChapter(opf.spine.indexOf(chapter), opf.manifest[chapter]!.href));
      }
      state = state.copyWith(author: opf.author, title: opf.title, manifest: opf.manifest, chapters: chapters, parsingBook: false);
    } catch (e, s) {
      state = state.copyWith(error: s);
    }
  }

}