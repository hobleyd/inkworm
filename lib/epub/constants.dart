import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'epub.dart';

part 'constants.g.dart';

@Riverpod(keepAlive: true)
class PageConstants extends _$PageConstants {
  static double canvasWidth = 0;
  static double canvasHeight = 0;
  static double leftIndent = 12;
  static double rightIndent = 12;
  static double pixelDensity = 1;

  @override
  void build() {}

  void setConstraints({required double height, required double width}) {
    if (height != canvasHeight || width != canvasWidth) {
      debugPrint('resetting width/height from $canvasWidth/$canvasHeight to $width/$height');
      canvasHeight = height;
      canvasWidth = width;

      Future.delayed(Duration(seconds: 0), () => ref.read(epubProvider.notifier).parse());
    }
  }
}