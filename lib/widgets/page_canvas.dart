import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../epub/structure/epub_chapter.dart';
import '../epub/structure/line.dart';
import '../models/page_size.dart';
import '../providers/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';
import '../providers/progress.dart';
import '../providers/theme.dart';
import '../screens/settings.dart';
import 'page_renderer.dart';

class PageCanvas extends ConsumerStatefulWidget {
  const PageCanvas({super.key});

  @override
  ConsumerState<PageCanvas> createState() => _PageCanvas();
}

class _PageCanvas extends ConsumerState<PageCanvas> {
  static const EdgeInsets _pagePadding = EdgeInsets.only(top: 6, bottom: 6);
  final pageSize = GetIt.instance.get<PageSize>();
  int lastPageNumber = -1;

  @override
  Widget build(BuildContext context,) {
    EpubBook     book = ref.watch(epubProvider);
    var progressAsync = ref.watch(progressProvider);

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
          // an isolate). The page number check is required during development as parsing errors can result in weird numbering if I fuck up.
          final EpubChapter? chapter = book.chapters.elementAtOrNull(progress.chapterNumber);
          int pageNumber = progress.pageNumber >= 0 ? progress.pageNumber : 0;
          if (chapter != null) {
            if (pageNumber >= chapter.pages.length) {
              pageNumber = chapter.pages.length-1;
            }
          }
          final List<Line> lines = chapter?[pageNumber]?.lines ?? [];
          final List<Line> foots = chapter?[pageNumber]?.footnotes ?? [];
          PageRenderer renderer = PageRenderer(lines: lines, footnotes: foots);
          if (lastPageNumber != progress.pageNumber && lines.isNotEmpty) {
            renderer.needsRepaint = true;
            setState(() {
              lastPageNumber = progress.pageNumber;
            });
          }

          return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth != pageSize.canvasWidth || constraints.maxHeight - _pagePadding.vertical != pageSize.canvasHeight) {
                  pageSize.update(canvasWidth: constraints.maxWidth, canvasHeight: constraints.maxHeight - _pagePadding.vertical,);
                }

                return Container(
                  padding: _pagePadding,
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
              },
          );
        });
  }
}
