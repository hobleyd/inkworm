import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkworm/epub/epub_chapter.dart';

import '../epub/constants.dart';
import '../epub/epub.dart';
import '../widgets/page_renderer.dart';

class Inkworm extends ConsumerStatefulWidget {
  int pageNumber = 0;
  Inkworm({super.key, required this.pageNumber});

  @override
  ConsumerState<Inkworm> createState() => _Inkworm();
}

class _Inkworm extends ConsumerState<Inkworm> {
  int displayedPage = 0;

  @override
  Widget build(BuildContext context) {
    List<EpubChapter> chapters = ref.watch(epubProvider);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Container(
          height: PageConstants.canvasHeight,
          width: PageConstants.canvasWidth,
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: GestureDetector(
              onTapUp: (TapUpDetails details) {
                double screenWidth = MediaQuery.of(context).size.width;
                double tapX = details.globalPosition.dx;

                setState(() {
                  if (tapX < screenWidth / 2) {
                    if (displayedPage > 0) {
                      displayedPage--;
                    }
                  } else {
                    // TODO: deal with end of chapter!
                    displayedPage++;
                  }
                });
                    },
            child: chapters.isEmpty
              ? Text("waiting to parse book")
              : CustomPaint(painter: PageRenderer(ref, displayedPage),),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    displayedPage = widget.pageNumber;

    Future.delayed(Duration(seconds: 0), () => ref.read(epubProvider.notifier).parse(context, ""));
  }
}
