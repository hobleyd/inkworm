import 'dart:async';

import 'package:injectable/injectable.dart';

@lazySingleton
class PageSize {
  final StreamController<PageSize> _controller = StreamController<PageSize>();
  double canvasWidth;
  double canvasHeight;
  double pixelDensity;
  double leftIndent;
  double rightIndent;

  Stream<PageSize> get stream => _controller.stream;

  PageSize() : canvasWidth = 0, canvasHeight = 0, pixelDensity = 1, leftIndent = 12, rightIndent = 12;

  void closeStream() {
    _controller.close();
  }

  void update({double? canvasWidth, double? canvasHeight, double? pixelDensity, double? leftIndent, double? rightIndent}) {
    bool sendUpdate = false;
    if (canvasWidth != null && this.canvasWidth != canvasWidth || canvasHeight != null && this.canvasHeight != canvasHeight) {
      sendUpdate = true;
    }

    this.canvasWidth = canvasWidth ?? this.canvasWidth;
    this.canvasHeight = canvasHeight ?? this.canvasHeight;
    this.pixelDensity = pixelDensity ?? this.pixelDensity;
    this.leftIndent = leftIndent ?? this.leftIndent;
    this.rightIndent = rightIndent ?? this.rightIndent;

    if (sendUpdate) {
      _controller.sink.add(this);
    }
  }

  @override
  String toString() {
    return 'width: $canvasWidth / height: $canvasHeight';
  }
}