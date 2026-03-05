import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../epub/interfaces/isolate_listener.dart';
import 'page_size_isolate_listener.dart';

@lazySingleton
class PageSize {
  IsolateListener? isolateListener;

  double canvasWidth;
  double canvasHeight;
  double pixelDensity;
  double leftIndent;
  double rightIndent;

  PageSize() : canvasWidth = 0, canvasHeight = 0, pixelDensity = 1, leftIndent = 12, rightIndent = 12;

  void update({double? canvasWidth, double? canvasHeight, double? pixelDensity, double? leftIndent, double? rightIndent}) {
    bool sizeChanged = false;
    if ((canvasWidth != null && canvasWidth != this.canvasWidth) || (canvasHeight != null && canvasHeight != this.canvasHeight)) {
      sizeChanged = true;
    }

    this.canvasWidth  = canvasWidth  ?? this.canvasWidth;
    this.canvasHeight = canvasHeight ?? this.canvasHeight;
    this.pixelDensity = pixelDensity ?? this.pixelDensity;
    this.leftIndent   = leftIndent   ?? this.leftIndent;
    this.rightIndent  = rightIndent  ?? this.rightIndent;

    if (sizeChanged) {
      PageSizeIsolateListener sizeListener = GetIt.instance.get<PageSizeIsolateListener>();
      sizeListener.isolateListener?.onSizeChanged(this);
    }
  }

  @override
  String toString() {
    return 'width: $canvasWidth / height: $canvasHeight';
  }
}