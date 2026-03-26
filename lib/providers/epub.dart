import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  final OpenEpubRequest _epubRequest = OpenEpubRequest(href: "");
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
    state = state.copyWith(chapters: _chapters);

    if (parsed) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.complete);
      _worker?.close();
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
    if (ref.read(bookStateManagementProvider).hasNone(BookState.parsing|BookState.complete)) {
      ref.read(bookStateManagementProvider.notifier).set(BookState.parsing);
      _worker?.openBook(_epubRequest);
    }
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }

  void setProgress(ReadingProgress progress) {
    state = state.copyWith(uri: progress.book);

    if (_epubRequest.update(fontSize: progress.fontSize, initialChapter: progress.chapterNumber,)) {
      openBookInIsolate();
    }
  }
}
