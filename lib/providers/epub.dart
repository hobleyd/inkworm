import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import '../models/epub_book.dart';
import '../epub/elements/epub_chapter.dart';
import '../epub/parser/epub_parser.dart';
import '../epub/parser/extensions.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  late List<EpubChapter> _chapters;

  @override
  EpubBook build() {
    return EpubBook(uri: "", author: "", title: "", chapters: [], manifest: {}, parsingBook: true);
  }

  /*
   * When parsing the book, parse the current chapter (the first on initial reading) and then one on either side to allow
   * the reader to continue reading while we complete the book parsing.
   */
  void parse(int fromChapterNumber) async {
    try {
      XmlDocument opf = GetIt.instance.get<EpubParser>().parse();

      _chapters = List.generate(opf.spine.length, (int index) => EpubChapter(chapterNumber: index), growable: false);
      _chapters[fromChapterNumber] = await parseChapter(opf, fromChapterNumber);

      // Allow the page to be rendered.
      state = state.copyWith(author: opf.author, title: opf.title, manifest: opf.manifest, chapters: _chapters);

      parseRemainingChapters(opf, fromChapterNumber);
    } catch (e, s) {
      state = state.copyWith(errorDescription: e.toString(), error: s);
    }
  }

  Future <EpubChapter> parseChapter(XmlDocument opf, int chapterIndex) async {
    return await GetIt.instance.get<EpubParser>().parseChapter(chapterIndex, opf.manifest[opf.spine[chapterIndex]]!.href);
  }

  Future<void> parseRemainingChapters(XmlDocument opf, int chapterIndex) async {
    Set<int> completedChapters = { chapterIndex };
    if (chapterIndex < _chapters.length) {
      _chapters[chapterIndex+1] = await parseChapter(opf, chapterIndex+1);
      state = state.copyWith(chapters: _chapters);
    }

    if (chapterIndex > 0) {
      await parseChapter(opf, chapterIndex-1);
      _chapters[chapterIndex-1] = await parseChapter(opf, chapterIndex-1);
      state = state.copyWith(chapters: _chapters);
    }

    for (int chapterIndex = 0; chapterIndex < _chapters.length; chapterIndex++) {
      if (completedChapters.contains(chapterIndex)) {
        continue;
      }
      _chapters[chapterIndex] = await parseChapter(opf, chapterIndex);
      state = state.copyWith(chapters: _chapters);
    }
    state = state.copyWith(parsingBook: false);
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }
}