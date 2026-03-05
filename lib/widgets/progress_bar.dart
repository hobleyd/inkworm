import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkworm/models/book_state.dart';
import 'package:inkworm/providers/progress.dart';

import '../providers/book_state_management.dart';
import '../providers/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';

class ProgressBar extends ConsumerWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While we don't do anything with bookState, it is used to trigger the rebuild on change so that we can drive the
    // UI updates off the notifier, below.
    BookState bookState = ref.watch(bookStateManagementProvider);

    String chapterProgress = 'Analysing the eBook; please be patient...';
    String title = '';
    String author = '';

    if (bookState.hasAll(BookState.complete)) {
      var progressAsync = ref.watch(progressProvider);
      EpubBook book = ref.watch(epubProvider);

      if (progressAsync.hasValue) {
        ReadingProgress progress = progressAsync.value!;
        chapterProgress = progress.chapterNumber > 0
          ? '${book.currentPageNumber(progress.chapterNumber, progress.pageNumber)}-${book.nextChapterPageNumber(progress.chapterNumber)}/${book.totalPages}'
          : '';
      }
    }
    if (bookState.hasAll(BookState.details)) {
      EpubBook book = ref.watch(epubProvider);
      // TODO: this should be dynamic based on screen width.
      title = book.title.length > 30 ? '${book.title.substring(0, 27)}...' : book.title;
      author = book.author;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Stack(
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(title, style: Theme.of(context).textTheme.labelSmall)),
          Align(alignment: Alignment.center, child: Text(chapterProgress, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
          Align(alignment: Alignment.centerRight, child: Text(author, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall)),
        ],
      ),
    );
  }
}