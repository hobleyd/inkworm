import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/providers/progress.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/reading_db.dart';
import '../epub/cache/image_cache.dart';
import '../epub/interfaces/isolate_listener.dart';
import '../epub/parser/isolates/isolate_worker.dart';
import '../epub/parser/isolates/requests/open_epub_request.dart';
import '../epub/structure/epub_chapter.dart';
import '../models/book_state.dart';
import '../models/epub_book.dart';
import '../models/page_size.dart';
import '../models/page_size_isolate_listener.dart';
import '../models/reading_progress.dart';
import 'book_state_management.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub implements IsolateListener {
  OpenEpubRequest _epubRequest = OpenEpubRequest(href: "");
  IsolateWorker? _worker;

  late List<EpubChapter> _chapters;
  late int _spineLength;
  late Stopwatch _stopwatch;

  bool get parsed => _chapters.where((chapter) => chapter.pages.isEmpty).isEmpty;

  @override
  EpubBook build() {
    Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.created));

    // Required because we can't pass callbacks into an isolate; hence separating from the
    // PageSize object which is passed through.
    PageSizeIsolateListener sizeListener = GetIt.instance.get<PageSizeIsolateListener>();
    sizeListener.setListener(this);

    return EpubBook(uri: "", author: "", title: "", chapters: []);
  }

  @override
  void onBookDetails(String author, String title, int spineLength) {
    state = state.copyWith(author: author, title: title);
    _spineLength = spineLength;

    _chapters = List.generate(_spineLength, (int index) => EpubChapter(chapterNumber: index), growable: false);

    ref.read(bookStateManagementProvider.notifier).set(BookState.details);
  }

  @override
  void onError(String error, String stackTrace) {
      state = state.copyWith(errorDescription: error, error: StackTrace.fromString(stackTrace));
  }

  @override
  Future<void> onIsolatesInitialised() async {
    _epubRequest.isolatesReady = true;

    if (_epubRequest.requestComplete) {
      openBookInIsolate();
    }
  }

  @override
  void onParsedChapter(EpubChapter chapter) {
    _chapters[chapter.chapterNumber] = chapter;
    state = state.copyWith(chapters: List.from(_chapters));

    if (parsed) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.complete);
      _worker?.close();
      _worker = null;

      _stopwatch.stop();
      debugPrint('parsing took: ${_stopwatch.elapsed.inMilliseconds} milliseconds');
    }
  }

  // Called when the size changes and is passed to the parsing isolate.
  @override
  void onSizeChanged(PageSize size) async {
    if (_epubRequest.update(pageSize: size)) {
      openBookInIsolate();
    }
  }

  void openBook(String book) async {
    // This gets called from the Inkworm build function, so let's ensure we only action it the first time.
    if (_epubRequest.href != book) {
      _worker ??= IsolateWorker(listener: this);

      String css = await rootBundle.loadString('assets/default.css');
      _epubRequest.update(href: book, css: css);

      state = state.copyWith(uri: book);
    }
  }

  void openBookInIsolate() {
    // Due to the async nature of Riverpod updates, this can get called more than once; ignore subsequent calls unless we have tweaked state to pay attention.
    if (ref.read(bookStateManagementProvider).hasNone(BookState.parsing|BookState.complete)) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.parsing);
      debugPrint('starting timer for parsing');
      _stopwatch = Stopwatch()..start();

      _worker?.openBook(_epubRequest);
    }
  }

  // Called when we open a new book
  void resetBook(String book) async {
    ImageCache cache = GetIt.instance.get<ImageCache>();
    cache.clear();

    _worker = null;
    _epubRequest = OpenEpubRequest(href: "", pageSize: _epubRequest.pageSize,);
    ref.read(bookStateManagementProvider.notifier).clear();

    state = EpubBook(uri: book, author: "", title: "", chapters: []);

    final progress = await ref.read(readingDBProvider.notifier).getReadingProgress(book);
    ref.read(progressProvider.notifier).setProgress(book, progress.fontSize, progress.chapterNumber, progress.pageNumber);
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }

  void setProgress(ReadingProgress progress) {
    if (state.uri != progress.book) {
      state = state.copyWith(uri: progress.book);
    }

    if (_epubRequest.update(fontSize: progress.fontSize, initialChapter: progress.chapterNumber,)) {
      openBookInIsolate();
    }

  }
}
