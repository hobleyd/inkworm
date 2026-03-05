import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../../models/element_size.dart';

@lazySingleton
class TextCache {
  final Map<String, ElementSize> _cache = {};

  ElementSize? get(String text, TextStyle style) => _cache[getKey(text, style)];

  void addCacheElement(String text, TextStyle style, ElementSize size) {
    final String key = getKey(text, style);
    if (!_cache.containsKey(key)) {
      _cache[key] = size;
    }
  }

  bool contains(String text, TextStyle style) {
    return _cache.containsKey(getKey(text, style));
  }

  String getKey(String text, TextStyle style) {
    return [
      text,
      style.fontSize?.toStringAsFixed(3) ?? 'null',
      style.fontFamily                   ?? 'null',
      style.fontWeight?.index.toString() ?? 'null',
      style.fontStyle?.index.toString()  ?? 'null',
    ].join('|');
  }
}