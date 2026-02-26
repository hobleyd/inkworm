import '../content/html_content.dart';

class ElementSize {
  double height;
  double width;

  ElementSize({required this.height, required this.width});
}

class MeasureCache {
  final Map<HtmlContent, ElementSize> _cache = {};

  void addCacheElement(HtmlContent key, {required double width, required double height}) {
    if (_cache.containsKey(key)) {
      _cache[key] = ElementSize(height: height, width: width);
      return;
    }
  }

  String _measureCacheKey({
  required String text,
  required double? fontSize,
  required String? fontFamily,
  required int? fontWeightIndex,
  required int? fontStyleIndex,
  required bool isHorizontal,
}) {
  return [
    text,
    fontSize?.toStringAsFixed(3) ?? 'null',
    fontFamily ?? 'null',
    fontWeightIndex?.toString() ?? 'null',
    fontStyleIndex?.toString() ?? 'null',
    isHorizontal ? 'h' : 'v',
  ].join('|');
}

}