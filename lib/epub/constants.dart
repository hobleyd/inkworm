import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  bool setConstraints({required double height, required double width}) {
    if (height != canvasHeight || width != canvasWidth) {
      canvasHeight = height;
      canvasWidth = width;

      return true;
    }

    return false;
  }
}