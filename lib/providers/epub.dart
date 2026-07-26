import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
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
import 'progress.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub implements IsolateListener {
  OpenEpubRequest _epubRequest = OpenEpubRequest(href: "");
  IsolateWorker? _worker;

  late List<EpubChapter> _chapters;
  late int _spineLength;

  // Resolved once the reopen triggered by repaginate() finishes parsing. Unlike
  // BookState's bits (which latch permanently once set and so can't tell "a
  // reopen is currently running" from "a reopen has ever run"), this is scoped
  // to a single reopen and is the reliable signal callers need to wait on.
  Completer<void>? _repaginationDone;

  bool get    parsed => _chapters.where((chapter) => chapter.pages.isEmpty).isEmpty;
  int  get remaining => _chapters.where((chapter) => chapter.pages.isEmpty).length;

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
    ref.read(bookStateManagementProvider.notifier).set(BookState.details);

    state = state.copyWith(author: author, title: title);
    _spineLength = spineLength;

    _chapters = List.generate(_spineLength, (int index) => EpubChapter(chapterNumber: index), growable: false);

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (ref.read(bookStateManagementProvider).hasNone(BookState.sized)) {
        Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.sized));
        await openBook(state.uri);
        openBookInIsolate();
      }
    });
  }

  @override
  void onError(String error, String stackTrace) {
      state = state.copyWith(errorDescription: error, error: StackTrace.fromString(stackTrace));
  }

  @override
  Future<void> onIsolatesInitialised() async {
    ref.read(bookStateManagementProvider.notifier).set(BookState.initialised);

    _worker!.getBookDetails(state.uri);
  }

  @override
  void onParsedChapter(EpubChapter chapter) {
    _chapters[chapter.chapterNumber] = chapter;
    state = state.copyWith(chapters: List.from(_chapters));

    if (parsed) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.complete);
      _worker?.close();
      _worker = null;

      _repaginationDone?.complete();
      _repaginationDone = null;
    }
  }

  // This gets called twice - once when the UI is created and again once the Book Details have been returned and we have the correct size.
  // The first time we trigger Isolate creation; the second we'll trigger book parsing.
  //
  // Once the book has completed its initial parse, later calls (from ordinary
  // window resizes) only need to keep _epubRequest.pageSize current — actually
  // triggering a reflow at the new size is repaginate()'s job. That matters
  // because this method is async: without the complete-bit guard below, its
  // continuation after `await openBook(...)` can still be pending when a
  // repagination-triggered resetBook() runs and clears BookState, and it would
  // then stomp BookState.sized back on for the *new* reopen cycle, fooling
  // onBookDetails's fallback into thinking sizing already happened and
  // skipping the real openBookInIsolate() call.
  @override
  void onSizeChanged(PageSize size) async {
    var bookState = ref.read(bookStateManagementProvider);

    _epubRequest.update(pageSize: size);
    if (bookState.hasNone(BookState.details) && _worker == null) {
      _worker ??= IsolateWorker(listener: this);
    }

    if (bookState.hasAll(BookState.initialised|BookState.details) && bookState.hasNone(BookState.complete)){
      Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.sized));

      await openBook(state.uri);
      openBookInIsolate();
    }
  }

  Future<void> openBook(String book) async {
    // This gets called from the Inkworm build function, so let's ensure we only action it the first time.
    if (_epubRequest.href != book) {
      String css = await rootBundle.loadString('assets/default.css');
      _epubRequest.update(href: book, css: css);

      state = state.copyWith(uri: book);
    }
  }

  void openBookInIsolate() {
    // Due to the async nature of Riverpod updates, this can get called more than once; ignore subsequent calls unless we have tweaked state
    // to pay attention.
    if (ref.read(bookStateManagementProvider).hasNone(BookState.parsing|BookState.complete)) {
      Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.parsing));

      _worker?.openBook(_epubRequest);
    }
  }

  // Called when we open a new book
  void resetBook(String book) async {
    ImageCache cache = GetIt.instance.get<ImageCache>();
    cache.clear();

    ref.read(bookStateManagementProvider.notifier).clear();
    state = EpubBook(uri: book, author: "", title: "", chapters: []);

    final progress = await ref.read(readingDBProvider.notifier).getReadingProgress(book);
    ref.read(progressProvider.notifier).setProgress(book, progress.fontSize, progress.chapterNumber, progress.pageNumber);

    _epubRequest = OpenEpubRequest(href: "", pageSize: _epubRequest.pageSize, fontSize: progress.fontSize, initialChapter: progress.chapterNumber);

    _worker = IsolateWorker(listener: this);
    openBook(book);
  }

  // Reopens and reparses the book at the current PageSize (e.g. after a window
  // resize), returning a Future that resolves once the new pagination is
  // complete. Only one repagination can be in flight at a time — if one is
  // already running, its Future is returned instead of starting another,
  // since resetBook doesn't close the previous worker before replacing it.
  Future<void> repaginate(String book) {
    if (_repaginationDone != null) return _repaginationDone!.future;

    _repaginationDone = Completer<void>();
    resetBook(book);
    return _repaginationDone!.future;
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }

  void setProgress(ReadingProgress progress) {
    Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.progress));
    _epubRequest.update(fontSize: progress.fontSize, initialChapter: progress.chapterNumber,);

    if (state.uri != progress.book) {
      state = state.copyWith(uri: progress.book);
    }

    var bookState = ref.read(bookStateManagementProvider);
    if (bookState.hasNone(BookState.initialised)) {
        openBook(progress.book);
    }
  }
}
