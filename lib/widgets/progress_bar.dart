import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/epub.dart';
import '../models/epub_book.dart';

class ProgressBar extends ConsumerWidget {

  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.watch(epubProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(6, 3, 6, 3),
      child: Stack(
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(book.title, style: Theme.of(context).textTheme.labelSmall)),
          Align(alignment: Alignment.center, child: Text('1-1/1', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
          Align(alignment: Alignment.centerRight, child: Text(book.author, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall)),
        ],
      ),
    );
  }
}