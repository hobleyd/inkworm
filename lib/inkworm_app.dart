import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme.dart';
import 'screens/inkworm.dart';

class InkwormApp extends ConsumerWidget {
  const InkwormApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Paladin',
      home: Inkworm(),
      theme: ref.watch(themeProvider),
    );
  }
}
