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
    BookState bookState = ref.watch(bookStateManagementProvider);
    EpubBook       book = ref.watch(epubProvider);

    var epubNotifier = ref.read(epubProvider.notifier);
    String chapterProgress = 'Analysing the eBook';
    if (bookState.hasAny(BookState.details|BookState.parsing)) {
      chapterProgress += ': ${epubNotifier.empty} chapters to go.';
    }

    if (bookState.hasAll(BookState.complete)) {
      var progressAsync = ref.watch(progressProvider);
      if (progressAsync.hasValue) {
        ReadingProgress progress = progressAsync.value!;
        chapterProgress = progress.chapterNumber > 0
          ? '${book.currentPageNumber(progress.chapterNumber, progress.pageNumber)}-${book.nextChapterPageNumber(progress.chapterNumber)}/${book.totalPages}'
          : '';
      }
    }

    final Widget left   = Text(book.title, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall);
    final Widget centre = Text(chapterProgress, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall);
    final Widget right  = Text(book.author, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Stack(
        alignment: Alignment.center,
        children: [
          centre,
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRect(
                    child: left,
                  ),
                ),
              ),
              Opacity(
                opacity: 0,
                child: IgnorePointer(child: centre),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ClipRect(
                    child: right,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}