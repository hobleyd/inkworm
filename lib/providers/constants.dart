import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/page_size.dart';

part 'constants.g.dart';

@Riverpod(keepAlive: true)
class PageConstants extends _$PageConstants {

  @override
  PageSize build() {
    
  }

  bool setConstraints({required double height, required double width}) {
    if (height != canvasHeight || width != canvasWidth) {
      canvasHeight = height;
      canvasWidth = width;

      return true;
    }

    return false;
  }
}