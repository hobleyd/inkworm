import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'epub/constants.dart';
import 'providers/theme.dart' hide Theme;
import 'screens/inkworm.dart';

class InkwormApp extends ConsumerWidget {
  const InkwormApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PageConstants.setConstraints(height: MediaQuery.of(context).size.height, width: MediaQuery.of(context).size.width);

    return MaterialApp(
      title: 'Inkworm',
      home: Inkworm(pageNumber: 0),
      theme: ref.watch(themeProvider),
    );
  }
}
