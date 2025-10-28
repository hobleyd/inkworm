import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:inkworm/epub/constants.dart';

import '../content/image_content.dart';
import 'line_element.dart';

@immutable
class ImageElement extends LineElement {
  final ImageContent image;

  double get canvasWidth => PageConstants.canvasWidth - PageConstants.leftIndent - PageConstants.rightIndent;
  double get canvasHeight => PageConstants.canvasHeight;

  @override
  get element => image;

  @override
  get style => image.blockStyle;

  ImageElement({required this.image}) {
    getConstraints();
  }

  @override
  void getConstraints() {
    // Resize the image to fit the screen.
    if (image.width > canvasWidth || image.height > canvasHeight) {
      double aspectRatio = image.width / image.height;

      double newWidth = canvasWidth;
      double newHeight = canvasHeight;

      if (aspectRatio > canvasWidth / canvasHeight) {
        newHeight = canvasWidth / aspectRatio;
      } else {
        newWidth = canvasHeight * aspectRatio;
      }

      width = newWidth * image.blockStyle.maxWidth;
      height = newHeight * image.blockStyle.maxHeight;
    } else {
      width = image.width;
      height = image.height;
    }
  }

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    c.drawImageRect(
      image.image,
      Rect.fromLTWH(0, 0, image.width, image.height),
      Rect.fromLTWH(xPos, yPos, width, this.height),
      Paint(),
    );
    //c.drawImage(image.image, Offset(xPos, yPos), Paint());
  }

  @override
  String toString() {
    return "[IMG]";
  }
}