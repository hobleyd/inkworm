import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import '../models/epub_book.dart';
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
      progress.book = book;
      progress.chapterNumber = 0;
      progress.pageNumber = 0;
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
      opf = GetIt.instance.get<EpubParser>().getOPF();

      _chapters = List.generate(opf.spine.length, (int index) => EpubChapter(chapterNumber: index), growable: false);
      _chapters[fromChapterNumber] = await parseChapter(fromChapterNumber);

      // Allow the page to be rendered.
      state = state.copyWith(author: opf.author, title: opf.title, chapters: _chapters);

      //Isolate.run(() => parseRemainingChapters(fromChapterNumber));
      parseRemainingChapters(fromChapterNumber);
    } catch (e, s) {
      state = state.copyWith(errorDescription: e.toString(), error: s);
    }
  }

  Future <EpubChapter> parseChapter(int chapterIndex) async {
    return await GetIt.instance.get<EpubParser>().parseChapter(chapterIndex, opf.manifest[opf.spine[chapterIndex]]!.href);
  }

  Future<void> parseRemainingChapters(int chapterIndex) async {
    Set<int> completedChapters = { chapterIndex };
    if (chapterIndex+1 < _chapters.length) {
      _chapters[chapterIndex+1] = await parseChapter(chapterIndex+1);
      completedChapters.add(chapterIndex+1);
      state = state.copyWith(chapters: _chapters);
    }

    if (chapterIndex > 0) {
      await parseChapter(chapterIndex-1);
      _chapters[chapterIndex-1] = await parseChapter(chapterIndex-1);
      completedChapters.add(chapterIndex-1);
      state = state.copyWith(chapters: _chapters);
    }

    for (int chapterIndex = 0; chapterIndex < opf.spine.length; chapterIndex++) {
      if (completedChapters.contains(chapterIndex)) {
        continue;
      }
      _chapters[chapterIndex] = await parseChapter(chapterIndex);
      state = state.copyWith(chapters: _chapters);
    }
    state = state.copyWith(parsingBook: false);
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }
}