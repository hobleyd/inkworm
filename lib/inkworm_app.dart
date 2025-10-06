import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'epub/epub.dart';
import 'providers/theme.dart' hide Theme;
import 'screens/inkworm.dart';

class InkwormApp extends ConsumerWidget {
  const InkwormApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Epub.instance.setConstraints(height: MediaQuery.of(context).size.height, width: MediaQuery.of(context).size.width);
    Epub.instance.parse(context, ""); // TODO: accept filename from Intent.

    return MaterialApp(
      title: 'Inkworm',
      home: Inkworm(pageNumber: 0),
      theme: ref.watch(themeProvider),
    );
  }
}
