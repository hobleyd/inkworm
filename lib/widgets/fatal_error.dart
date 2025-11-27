import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/epub_book.dart';
import '../providers/epub.dart';

class FatalError extends ConsumerWidget {
  const FatalError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.watch(epubProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Text('${book.errorDescription}\n${book.error}', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}