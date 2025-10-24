import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkworm/epub/constants.dart';

import '../epub/epub.dart';
import '../models/epub_book.dart';
import '../widgets/page_canvas.dart';
import '../widgets/progress_bar.dart';

class Inkworm extends ConsumerWidget {
  const Inkworm({super.key,});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.watch(epubProvider);

    MediaQueryData data = MediaQueryData.fromView(View.maybeOf(context)!);
    PageConstants.pixelDensity = data.devicePixelRatio;

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: book.error != null
                ? Text(book.error.toString())
                : PageCanvas(pageNumber: 0,),),
            ProgressBar(),
          ],
        ),
      ),
    );
    }
}
