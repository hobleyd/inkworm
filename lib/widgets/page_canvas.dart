import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../providers/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';
import '../providers/progress.dart';
import '../screens/settings.dart';
import 'page_renderer.dart';

class PageCanvas extends ConsumerWidget {
  const PageCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.read(epubProvider);
    var progressAsync =  ref.watch(progressProvider);

    return progressAsync.when(
        error: (error, stackTrace) {
          return Text('');
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        data: (ReadingProgress progress) {
          debugPrint('PageCanvas: progress: $progress (${book.uri}');
          if (book.uri.isNotEmpty && book.uri != progress.book) {
            progress = GetIt.instance.get<ReadingProgress>();
            progress.book = book.uri;
            progress.chapterNumber = 0;
            progress.pageNumber = 0;

            debugPrint('resetting progress');
            ref.read(progressProvider.notifier).setProgress(book.uri, 0, 0);
          } else if (book.uri.isEmpty && progress.book.isNotEmpty) {
            Future(() => ref.read(epubProvider.notifier).openBook(progress.book));
          }

          return Container(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: GestureDetector(
              onTapUp: (TapUpDetails details) {
                double screenWidth = MediaQuery.of(context).size.width;
                double tapX = details.globalPosition.dx;

                if (tapX < screenWidth * 0.33) {
                  if (progress.pageNumber > 0) {
                    ref.read(progressProvider.notifier).setProgress(book.uri, progress.chapterNumber, progress.pageNumber - 1);
                  } else if (progress.chapterNumber > 0) {
                    final int chapter = progress.chapterNumber - 1;
                    ref.read(progressProvider.notifier).setProgress(book.uri, chapter, book[chapter].lastPageIndex);
                  }
                } else if (tapX > screenWidth * 0.66) {
                  if (progress.pageNumber == book[progress.chapterNumber].lastPageIndex) {
                    if (progress.chapterNumber < book.lastChapterIndex) {
                      ref.read(progressProvider.notifier).setProgress(book.uri, progress.chapterNumber + 1, 0);
                    }
                  } else {
                    ref.read(progressProvider.notifier).setProgress(book.uri, progress.chapterNumber, progress.pageNumber + 1);
                  }
                } else {
                  // TODO: display  menu
                  Navigator.push(context, MaterialPageRoute(builder: (context) => Settings())).then((onValue) {});
                }
              },
              child: CustomPaint(painter: PageRenderer(ref, progress.chapterNumber, progress.pageNumber),),
            ),
          );
        });
  }
}