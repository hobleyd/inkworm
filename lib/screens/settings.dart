import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkworm/widgets/exit_inkworm.dart';

import '../widgets/font_size_selector.dart';
import '../widgets/inkworm_update.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key,});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FontSize(),
            ExitInkworm(),
            Expanded(
              child: InkwormUpdate(),
        ),
      ],
      ),
      ),
    );
  }
}
