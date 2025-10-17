import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/epub.dart';
import '../models/epub_book.dart';
import 'page_renderer.dart';

class PageCanvas extends ConsumerStatefulWidget {
  int pageNumber = 0;

  @override
  ConsumerState<PageCanvas> createState() => _PageCanvas();
}

class _PageCanvas extends ConsumerState<PageCanvas> {
  int displayedPage = 0;

  @override
  Widget build(BuildContext context) {
    EpubBook book = ref.watch(epubProvider);

    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: GestureDetector(
        onTapUp: (TapUpDetails details) {
          double screenWidth = MediaQuery.of(context).size.width;
          double tapX = details.globalPosition.dx;

          setState(() {
            if (tapX < screenWidth / 3) {
              if (displayedPage > 0) {
                displayedPage--;
              }
            } else if (screenWidth -tapX > screenWidth / 3){
              // TODO: deal with end of chapter!
              displayedPage++;
            } else {
              // TODO: display  menu
            }
          });
        },
        child: CustomPaint(painter: PageRenderer(ref, displayedPage),),
      ),
    );
  }
}