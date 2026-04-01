
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:injectable/injectable.dart';

@LazySingleton()
class ImageCache {
  final Map<String, ui.Image> _imageCache = {};

  ui.Image operator[](String name) => _imageCache[name]!;

  void clear()               => _imageCache.clear();
  bool isCached(String name) => _imageCache.containsKey(name);

  Future<ui.Image> createImageFromUint8List(Uint8List imageData) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(imageData, (ui.Image image) {
      completer.complete(image);
    });
    return completer.future;
  }

  Future<void> addImage(String name, Uint8List image) async {
    _imageCache[name] = await createImageFromUint8List(image);
  }
}