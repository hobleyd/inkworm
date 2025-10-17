import 'package:flutter/material.dart';
import 'package:inkworm/epub/epub_chapter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import '../models/epub_book.dart';
import 'parser/epub_parser.dart';
import 'parser/extensions.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  EpubParser? epubParser;

  @override
  EpubBook build() {
    return EpubBook(author: "", title: "", chapters: [], manifest: {});
  }

  void parse(BuildContext context) {
    epubParser ??= EpubParser();

    try {
      epubParser!.openBook();
      XmlDocument opf = epubParser!.parse();

      List<EpubChapter> chapters = [];
      for (var chapter in opf.spine) {
        chapters.add(epubParser!.parseChapter(opf.spine.indexOf(chapter), opf.manifest[chapter]!.href));
      }
      state = state.copyWith(author: opf.author, title: opf.title, manifest: opf.manifest, chapters: chapters);
    } catch (e, s) {
      state = state.copyWith(error: s);
    }
  }

}