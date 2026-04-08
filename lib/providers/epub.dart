import 'package:flutter/foundation.dart';
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
    ref.read(bookStateManagementProvider.notifier).set(BookState.details);

    debugPrint('onBookDetails() -> ${ref.read(bookStateManagementProvider)}');
    state = state.copyWith(author: author, title: title);
    _spineLength = spineLength;

    _chapters = List.generate(_spineLength, (int index) => EpubChapter(chapterNumber: index), growable: false);

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (ref.read(bookStateManagementProvider).hasNone(BookState.sized)) {
        Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.sized));
        debugPrint('onBookDetails() fallback -> ${ref.read(bookStateManagementProvider)} -> open Book');
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

    debugPrint('onIsolatesInitialised() -> ${ref.read(bookStateManagementProvider)}');

    _worker!.getBookDetails(state.uri);
  }

  @override
  void onParsedChapter(EpubChapter chapter) {
    _chapters[chapter.chapterNumber] = chapter;
    state = state.copyWith(chapters: List.from(_chapters));

    debugPrint('received chapter: ${chapter.chapterNumber}, ${_chapters.where((chapter) => chapter.pages.isEmpty).length} to go!');
    if (parsed) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.complete);
      _worker?.close();
      _worker = null;
    }
  }

  // This gets called twice - once when the UI is created and again once the Book Details have been returned and we have the correct size.
  // The first time we trigger Isolate creation; the second we'll trigger book parsing.
  @override
  void onSizeChanged(PageSize size) async {
    var bookState = ref.read(bookStateManagementProvider);

    _epubRequest.update(pageSize: size);
    if (bookState.hasNone(BookState.details) && _worker == null) {
      debugPrint('onSizeChanged($size) -> ${ref.read(bookStateManagementProvider)} -> create Isolates');
      _worker ??= IsolateWorker(listener: this);
    }

    if (bookState.hasAll(BookState.initialised|BookState.details)){
      Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.sized));
      debugPrint('onSizeChanged($size) -> ${ref.read(bookStateManagementProvider)} -> open Book');

      await openBook(state.uri);
      openBookInIsolate();
    }
  }

  Future<void> openBook(String book) async {
    debugPrint('openBook() -> ${ref.read(bookStateManagementProvider)}');
    // This gets called from the Inkworm build function, so let's ensure we only action it the first time.
    if (_epubRequest.href != book) {
      String css = await rootBundle.loadString('assets/default.css');
      _epubRequest.update(href: book, css: css);

      state = state.copyWith(uri: book);
    }
  }

  void openBookInIsolate() {
    debugPrint('openBookInIsolate() -> ${ref.read(bookStateManagementProvider)}');
    // Due to the async nature of Riverpod updates, this can get called more than once; ignore subsequent calls unless we have tweaked state
    // to pay attention.
    if (ref.read(bookStateManagementProvider).hasNone(BookState.parsing|BookState.complete)) {
      Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.parsing));

      _worker?.openBook(_epubRequest);
    }
  }

  // Called when we open a new book
  void resetBook(String book) async {
    debugPrint('resetBook($book)');
    ImageCache cache = GetIt.instance.get<ImageCache>();
    cache.clear();

    ref.read(bookStateManagementProvider.notifier).clear();
    state = EpubBook(uri: book, author: "", title: "", chapters: []);

    final progress = await ref.read(readingDBProvider.notifier).getReadingProgress(book);
    ref.read(progressProvider.notifier).setProgress(book, progress.fontSize, progress.chapterNumber, progress.pageNumber);

    _epubRequest = OpenEpubRequest(href: "", pageSize: _epubRequest.pageSize, fontSize: progress.fontSize, initialChapter: progress.chapterNumber);

    _worker = null;
    openBook(book);
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }

  void setProgress(ReadingProgress progress) {
    Future(() => ref.read(bookStateManagementProvider.notifier).set(BookState.progress));
    debugPrint('setProgress(${progress.chapterNumber}/${progress.pageNumber}) -> ${ref.read(bookStateManagementProvider)}');
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
