import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/page_renderer.dart';

class Inkworm extends ConsumerWidget {
  const Inkworm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Container(child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: CustomPaint(
            painter: PageRenderer(),
          ),
        ),
        ),
      ),
    );
  }
}
