import 'package:injectable/injectable.dart';

import '../content/html_content.dart';
import '../content/image_content.dart';
import '../content/link_content.dart';
import '../content/text_content.dart';

class ElementSize {
  double height;
  double width;

  ElementSize({required this.height, required this.width});
}

@lazySingleton
class MeasureCache {
  final Map<String, ElementSize> _cache = {};

  ElementSize? operator[](HtmlContent content) => _cache[getKey(content: content)];

  void addCacheElement(HtmlContent content, {required double width, required double height}) {
    final String key = getKey(content: content);
    if (!_cache.containsKey(key)) {
      _cache[key] = ElementSize(height: height, width: width);
    }
  }

  bool contains(HtmlContent content) {
    return _cache.containsKey(getKey(content: content));
  }

  String createKey({required HtmlContent content}) {
    return [
      getKey(content: content),
      content.elementStyle.textStyle.fontSize?.toStringAsFixed(3) ?? 'null',
      content.elementStyle.textStyle.fontFamily ?? 'null',
      content.elementStyle.textStyle.fontWeight?.index.toString() ?? 'null',
      content.elementStyle.textStyle.fontStyle?.index.toString() ?? 'null',
    ].join('|');
  }

  String getKey({required HtmlContent content}) {
    return switch (content) {
      TextContent tc => tc.text,
      ImageContent ic => ic.image,
      LinkContent lc => (lc.src as TextContent).text,
      HtmlContent hc => throw FormatException,
    };
  }
}