import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';
import '../providers/progress.dart';
import '../providers/theme.dart';
import '../screens/settings.dart';
import 'page_renderer.dart';

class PageCanvas extends ConsumerWidget {
  const PageCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.watch(epubProvider);
    var progressAsync =  ref.watch(progressProvider);

    return progressAsync.when(
        error: (error, stackTrace) {
          return Text('');
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        data: (ReadingProgress progress) {
          Future(() => ref.read(themeProvider.notifier).setFontSize(progress.fontSize.toDouble()));

          // This is required to work around Flutter's desire not to repaint if nothing has changed; even though it has (from
          // an isolate).
          PageRenderer renderer =
          PageRenderer(    lines: book.chapters.elementAtOrNull(progress.chapterNumber)?[progress.pageNumber]?.lines ?? [],
                       footnotes: book.chapters.elementAtOrNull(progress.chapterNumber)?[progress.pageNumber]?.footnotes ?? []);
          renderer.needsRepaint = true;

          return Container(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: GestureDetector(
              onTapUp: (TapUpDetails details) {
                double screenWidth = MediaQuery.of(context).size.width;
                double tapX = details.globalPosition.dx;

                if (tapX < screenWidth * 0.33) {
                  if (progress.pageNumber > 0) {
                    ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, progress.chapterNumber, progress.pageNumber - 1);
                  } else if (progress.chapterNumber > 0) {
                    final int chapter = progress.chapterNumber - 1;
                    ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, chapter, book[chapter].lastPageIndex);
                  }
                } else if (tapX > screenWidth * 0.66) {
                  if (progress.pageNumber == book[progress.chapterNumber].lastPageIndex) {
                    if (progress.chapterNumber < book.lastChapterIndex) {
                      ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, progress.chapterNumber + 1, 0);
                    } else {
                      // Exit the app if we hit the last page and try to go right.
                      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                    }
                  } else {
                    ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, progress.chapterNumber, progress.pageNumber + 1);
                  }
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => Settings())).then((onValue) {});
                }
              },
              child: CustomPaint(painter: renderer,),
            ),
          );
        });
  }
}