import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../epub/interfaces/isolate_listener.dart';
import '../epub/parser/epub_parser_worker.dart';
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

  late List<EpubChapter> _chapters;
  late IsolateWorker _worker;
  late int _spineLength;


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
  }

  @override
  void onError(String error, String stackTrace) {
      state = state.copyWith(errorDescription: error, error: StackTrace.fromString(stackTrace));
  }

  @override
  void onParsedChapter(EpubChapter chapter) {
    _chapters[chapter.chapterNumber] = chapter;
    state = state.copyWith(chapters: _chapters);

    if (_chapters.where((chapter) => chapter.pages.isEmpty).isEmpty) {
      _worker.close();
    }
  }

  // Called when the size changes and is passed to the parsing isolate.
  @override
  void onSizeChanged(PageSize size) async {
    if (!ref.read(bookStateManagementProvider).hasAll(BookState.details)) {
      // TODO: Bodgy hack. This gets called twice, which we don't want. Once before and once after we set the BookDetail in the
      // ProgressBar. It only differs by a single pixel, but we should alter to work only after we have received the BookDetails
      // instead of the opposite which is happening now.
      _epubRequest.update(pageSize: size);
    }
  }

  void openBook(String book) async {
    _worker = IsolateWorker(listener: this);
    state = state.copyWith(uri: book);

    String css = await rootBundle.loadString('assets/default.css');
    _epubRequest.update(href: book, css: css);

    _worker.openBook(req);
  }

  void setError(String description, StackTrace stackTrace) {
    state = state.copyWith(errorDescription: description, error: stackTrace);
  }

  void setProgress(ReadingProgress progress) {
    ref.read(bookStateManagementProvider.notifier).set(BookState.progress);
    _epubRequest.update(fontSize: progress.fontSize, initialChapter: progress.chapterNumber,);
  }
}
