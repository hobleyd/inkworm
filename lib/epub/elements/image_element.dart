import 'package:flutter/material.dart' hide ImageCache;
import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../content/image_content.dart';
import '../cache/image_cache.dart';
import 'line_element.dart';

class ImageElement extends LineElement {
  final ImageContent image;

  @override
  get element => image;

  ImageElement({required this.image}) {
    getConstraints();
  }

  double calculateAspectRatio(double desiredWidth, double desiredHeight) {
    if (image.width > desiredWidth || image.height > desiredHeight) {
      final widthScale = desiredWidth / image.width;
      final heightScale = desiredHeight / image.height;

      return widthScale < heightScale ? widthScale : heightScale;
    }

    return 1;
  }

  @override
  Future<bool> getConstraints() async {
    // Resize the image to fit the screen.
    PageSize size = GetIt.instance.get<PageSize>();
    double scale = calculateAspectRatio(size.canvasWidth, size.canvasHeight);

    width = image.width * scale;
    height = image.height * scale;

    // If we need to scale the resized image, we can do this here. Making the assumption that
    // a) maxWidth or maxHeight are a percentage and that
    // b) you'd only specify 1 as otherwise you'll mess with the aspect ratio.
    if (image.blockStyle.maxWidth != null) {
      width = width * image.blockStyle.maxWidth!;
      height = height * image.blockStyle.maxWidth!;
    } else if (image.blockStyle.maxHeight != null) {
      width = width * image.blockStyle.maxHeight!;
      height = height * image.blockStyle.maxHeight!;
    }

    // TODO: look at how images with titles are handled and ensure we have enough space for both.
    if (height == size.canvasHeight) {
      width = width * 0.9;
      height = height * 0.9;
    }

    return true;
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    ImageCache cache = GetIt.instance.get<ImageCache>();

    c.drawImageRect(
      cache[image.image],
      Rect.fromLTWH(0, 0, image.width, image.height),
      Rect.fromLTWH(xPos, yPos, width, this.height),
      Paint(),
    );
  }

  @override
  String toString() {
    return "[IMG]";
  }
}
