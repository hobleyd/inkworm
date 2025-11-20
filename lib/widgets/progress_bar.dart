import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkworm/providers/progress.dart';

import '../epub/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';

class ProgressBar extends ConsumerWidget {

  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.watch(epubProvider);
    var progressAsync = ref.watch(progressProvider(book.uri));

    String pageNumbers = '';

    if (progressAsync.hasValue) {
      ReadingProgress progress = progressAsync.value!;

      // Don't display a page number on the title page
      pageNumbers = book.parsingBook || progress.chapterNumber == 0
          ? ''
          : '${book.currentPageNumber(progress.chapterNumber, progress.pageNumber)}-${book.nextChapterPageNumber(progress.chapterNumber)}/${book.totalPages}';
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 3, 6, 3),
      child: Stack(
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(book.title, style: Theme.of(context).textTheme.labelSmall)),
          if (book.parsingBook) ...[Align(alignment: Alignment.center, child: Text('Parsing eBook; please be patient', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall))],
          if (!book.parsingBook) ...[Align(alignment: Alignment.center, child: Text(pageNumbers, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall))],
          Align(alignment: Alignment.centerRight, child: Text(book.author, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall)),
        ],
      ),
    );
  }
}