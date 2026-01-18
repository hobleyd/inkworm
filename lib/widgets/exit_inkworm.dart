import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/epub_book.dart';
import '../providers/epub.dart';

class ExitInkworm extends ConsumerWidget {
  const ExitInkworm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextButton.icon(
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Exit Inkworm'),
          onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop')),
    );
  }
}