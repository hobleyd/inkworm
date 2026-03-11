import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../epub/interfaces/isolate_listener.dart';
import '../epub/parser/epub_parser_worker.dart';
import '../epub/structure/epub_chapter.dart';
import '../models/book_state.dart';
import '../models/epub_book.dart';
import '../models/page_size.dart';
import '../models/page_size_isolate_listener.dart';
import 'book_state_management.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub implements IsolateListener {
  late List<EpubChapter> _chapters;
  late EpubParserWorker _worker;
  late int _spineLength;
  late int _initialChapter;

  @override
  EpubBook build() {
    _worker = EpubParserWorker(isolateListener: this);
    Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.created));

    // Required because we can't pass callbacks into an isolate; hence separating from the
    // PageSize object which is passed through.
    PageSizeIsolateListener sizeListener = GetIt.instance.get<PageSizeIsolateListener>();
    sizeListener.setListener(this);

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

  @override
  void onBookDetails(String author, String title, int spineLength) {
    state = state.copyWith(author: author, title: title);
    _spineLength = spineLength;

    _chapters = List.generate(_spineLength, (int index) => EpubChapter(chapterNumber: index), growable: false);

    ref.read(bookStateManagementProvider.notifier).set(BookState.details);
    _worker.parseChapters(_initialChapter, _spineLength);
  }

  @override
  void onComplete() {
    if (_chapters.where((chapter) => chapter.pages.isEmpty).isEmpty) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.complete);
      // TODO: By doing this, I can't resize the window on a desktop. Not my biggest concern immediately, but something to consider.
      _worker.close();
    }
  }

  @override
  void onError(String error, String stackTrace) {
      state = state.copyWith(errorDescription: error, error: StackTrace.fromString(stackTrace));
  }

  @override
  void onInitialised(bool workerState) {
    if (workerState) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.initialised);
    }
  }

  @override
  void onParsedChapter(EpubChapter chapter) {
    _chapters[chapter.chapterNumber] = chapter;
    state = state.copyWith(chapters: _chapters);
  }

  // Called when the size changes and is passed to the parsing isolate.
  @override
  void onSizeChanged(PageSize size) async {
    if (!ref.read(bookStateManagementProvider).hasAll(BookState.details)) {
      // TODO: Bodgy hack. This gets called twice, which we don't want. Once before and once after we set the BookDetail in the
      // ProgressBar. It only differs by a single pixel, but we should alter to work only after we have received the BookDetails
      // instead of the opposite which is happening now.
      _worker.setPageSize(size);
    }
  }

  // Called by the parsing isolate once the Size change has been sent.
  @override
  void onSizeReceived() {
    getBookDetails(_initialChapter);
  }

  void openBook(String book) {
    state = state.copyWith(uri: book);
    _worker.openBook(book);
    _worker.parseDefaultCss();
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
