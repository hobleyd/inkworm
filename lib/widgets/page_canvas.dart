import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';
import '../providers/progress.dart';
import '../screens/settings.dart';
import 'page_renderer.dart';

class PageCanvas extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.watch(epubProvider);
    ReadingProgress progress =  ref.watch(progressProvider);

    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: GestureDetector(
        onTapUp: (TapUpDetails details) {
          double screenWidth = MediaQuery.of(context).size.width;
          double tapX = details.globalPosition.dx;

          if (tapX < screenWidth * 0.33) {
            if (progress.pageNumber > 0) {
              ref.read(progressProvider.notifier).setProgress(progress.chapterNumber, progress.pageNumber-1);
            } else if (progress.chapterNumber > 0) {
              final int chapter = progress.chapterNumber - 1;
              ref.read(progressProvider.notifier).setProgress(chapter, book[chapter].lastPageIndex);
            }
          } else if (tapX > screenWidth * 0.66) {
            if (progress.pageNumber == book[progress.chapterNumber].lastPageIndex) {
              if (progress.chapterNumber < book.lastChapterIndex) {
                ref.read(progressProvider.notifier).setProgress(progress.chapterNumber + 1, 0);
              }
            } else {
              ref.read(progressProvider.notifier).setProgress(progress.chapterNumber, progress.pageNumber + 1);
            }
          } else {
            // TODO: display  menu
            Navigator.push(context, MaterialPageRoute(builder: (context) => Settings())).then((onValue) {});
          }
        },
        child: CustomPaint(painter: PageRenderer(ref),),
      ),
    );
  }
}