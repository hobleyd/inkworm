import 'package:get_it/get_it.dart';
import 'package:inkworm/models/book_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/epub_book.dart';
import '../epub/parser/epub_parser_worker.dart';
import '../epub/structure/epub_chapter.dart';
import '../models/page_size.dart';
import '../models/reading_progress.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  late List<EpubChapter> _chapters;
  late EpubParserWorker _worker;
  late int _spineLength;
  late int _initialChapter;

  @override
  EpubBook build() {
    _worker = EpubParserWorker(
        onBookDetails:   onBookDetails,
        onError:         onError,
        onComplete:      onComplete,
        onInitialised:   onInitialised,
        onParsedChapter: onParsedChapter,
        onSizeReceived: onSizeReceived,
    );
    ref.read(bookStateManagementProvider.notifier).set(BookStateManagement.created);
    PageSize size = GetIt.instance.get<PageSize>();
    size.setOnSizeChanged(onSizeChanged);
    return EpubBook(uri: "", author: "", title: "", chapters: []);
  }

  /*
   * When parsing the book, parse the current chapter (the first on initial reading) and then one on either side to allow
   * the reader to continue reading while we complete the book parsing.
   */
  void getBookDetails(int chapterIndex) {
    _initialChapter = chapterIndex;
    _worker.getBookDetails();
  }

  void onBookDetails(String author, String title, int spineLength) {
    state = state.copyWith(author: author, title: title);
    _spineLength = spineLength;

    _chapters = List.generate(_spineLength, (int index) => EpubChapter(chapterNumber: index), growable: false);

    ref.read(bookStateManagementProvider.notifier).set(BookStateManagement.details);
    parseChapters(_initialChapter);
  }

  void onComplete() {
    if (_chapters.where((chapter) => chapter.pages.isEmpty).isEmpty) {
      ref.read(bookStateManagementProvider.notifier).set(BookStateManagement.complete);
    }
  }

  void onError(String error, String stackTrace) {
      state = state.copyWith(errorDescription: error, error: StackTrace.fromString(stackTrace));
  }

  void onInitialised(bool workerState) {
    if (workerState) {
      ref.read(bookStateManagementProvider.notifier).set(BookStateManagement.initialised);
    }
  }

  void onParsedChapter(int index, EpubChapter chapter) {
    _chapters[index] = chapter;
    state = state.copyWith(chapters: _chapters);
  }

  // Called when the size changes and is passed to the parsing isolate.
  void onSizeChanged(PageSize size) {
    _worker.setPageSize(size);
  }

  // Called by the parsing isolate once the Size change has been sent.
  void onSizeReceived() {
    getBookDetails(_initialChapter);
  }

  void openBook(String book) {
    state = state.copyWith(uri: book);
    _worker.openBook(book);
    _worker.parseDefaultCss();
  }

  /*
   * When parsing the book, parse the current chapter (the first on initial reading) and then one on either side to allow
   * the reader to continue reading while we complete the book parsing.
   */
  void parseChapters(int chapterIndex) {
    Set<int> completedChapters = { chapterIndex };

    _worker.parseChapter(_initialChapter);
    completedChapters.add(chapterIndex);

    if (chapterIndex+1 < _chapters.length) {
      //_worker.parseChapter(chapterIndex+1);
      completedChapters.add(chapterIndex+1);
    }

    if (chapterIndex > 0) {
      //_worker.parseChapter(chapterIndex-1);
      completedChapters.add(chapterIndex-1);
    }

    for (int chapterIndex = 0; chapterIndex < _spineLength; chapterIndex++) {
      if (completedChapters.contains(chapterIndex)) {
        continue;
      }
      //_worker.parseChapter(chapterIndex);
    }
  }

  void setInitialChapter(int chapter) {
    _initialChapter = chapter;
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }

  void setFontSize(int fontSize) {
    _worker.setFontSize(fontSize);
  }
}
