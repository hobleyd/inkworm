import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import 'epub_chapter.dart';
import '../models/epub_book.dart';
import 'parser/epub_parser.dart';
import 'parser/extensions.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  @override
  EpubBook build() {
    return EpubBook(author: "", title: "", chapters: [], manifest: {});
  }

  void parse() {
    try {
      GetIt.instance.get<EpubParser>().openBook();
      XmlDocument opf = GetIt.instance.get<EpubParser>().parse();

      List<EpubChapter> chapters = [];
      chapters.add(GetIt.instance.get<EpubParser>().parseChapter(0, opf.manifest["Cover"]!.href));
      //for (var chapter in opf.spine) {
      //  chapters.add(GetIt.instance.get<EpubParser>().parseChapter(opf.spine.indexOf(chapter), opf.manifest[chapter]!.href));
      ///}
      state = state.copyWith(author: opf.author, title: opf.title, manifest: opf.manifest, chapters: chapters);
    } catch (e, s) {
      state = state.copyWith(error: s);
    }
  }

}