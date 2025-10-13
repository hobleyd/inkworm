import 'package:flutter/foundation.dart';

class PageConstants {
  static double canvasWidth = 0;
  static double canvasHeight = 0;
  static double leftIndent = 12;
  static double rightIndent = 12;

  static void setConstraints({required double height, required double width}) {
    if (height != canvasHeight || width != canvasWidth) {
      debugPrint('setting height/width: $height/$width');
      canvasHeight = height;
      canvasWidth = width;
    }
  }
}