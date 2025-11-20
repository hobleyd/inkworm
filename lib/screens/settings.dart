import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/epub.dart';
import '../models/epub_book.dart';
import '../widgets/inkworm_update.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key,});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EpubBook book = ref.watch(epubProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkwormUpdate(),
        ),
      ],
      ),
      ),
    );
  }
}
