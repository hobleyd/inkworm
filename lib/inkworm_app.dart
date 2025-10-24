import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme.dart' hide Theme;
import 'screens/inkworm.dart';

class InkwormApp extends ConsumerWidget {
  const InkwormApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     return MaterialApp(
      title: 'Inkworm',
      home: Inkworm(),
      theme: ref.watch(themeProvider),
    );
  }
}
