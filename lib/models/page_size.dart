import 'package:injectable/injectable.dart';

@lazySingleton
class PageSize {
  void Function(PageSize size)? onSizeChanged;

  double canvasWidth;
  double canvasHeight;
  double pixelDensity;
  double leftIndent;
  double rightIndent;

  PageSize() : canvasWidth = 0, canvasHeight = 0, pixelDensity = 1, leftIndent = 12, rightIndent = 12;

  void setOnSizeChanged(Function(PageSize size) onSizeChanged) {
    this.onSizeChanged = onSizeChanged;
  }

  void update({double? canvasWidth, double? canvasHeight, double? pixelDensity, double? leftIndent, double? rightIndent}) {
    bool sizeChanged = false;
    if ((canvasWidth != null && canvasWidth != this.canvasWidth) || (canvasHeight != null && canvasHeight != this.canvasHeight)) {
      sizeChanged = true;
    }

    this.canvasWidth = canvasWidth ?? this.canvasWidth;
    this.canvasHeight = canvasHeight ?? this.canvasHeight;
    this.pixelDensity = pixelDensity ?? this.pixelDensity;
    this.leftIndent = leftIndent ?? this.leftIndent;
    this.rightIndent = rightIndent ?? this.rightIndent;

    if (sizeChanged && onSizeChanged != null) {
      onSizeChanged!(this);
    }
  }

  @override
  String toString() {
    return 'width: $canvasWidth / height: $canvasHeight';
  }
}