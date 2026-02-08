import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../../models/reading_progress.dart';
import '../parser/css_parser.dart';
import 'style.dart';

class ElementStyle extends Style {
  late CssParser _parser;
  late TextStyle textStyle;

  bool? isDropCaps;

  // Character: (superscript subscript)
  static const Map<String, ({String sup, String sub})> unicodeMap = {
    '0': (sup: '\u2070', sub: '\u2080'),
    '1': (sup: '\u00B9', sub: '\u2081'),
    '2': (sup: '\u00B2', sub: '\u2082'),
    '3': (sup: '\u00B3', sub: '\u2083'),
    '4': (sup: '\u2074', sub: '\u2084'),
    '5': (sup: '\u2075', sub: '\u2085'),
    '6': (sup: '\u2076', sub: '\u2086'),
    '7': (sup: '\u2077', sub: '\u2087'),
    '8': (sup: '\u2078', sub: '\u2088'),
    '9': (sup: '\u2079', sub: '\u2089'),
    'x': (sup: '\u02e3', sub: '\u2093'),
  };

  ElementStyle() {
    _parser = GetIt.instance.get<CssParser>();
    textStyle = TextStyle();

  }

  ElementStyle copyWith(ElementStyle parentStyle) {
    textStyle = textStyle.copyWith(
        color: parentStyle.textStyle.color,
        fontFamily: parentStyle.textStyle.fontFamily,
        fontSize: parentStyle.textStyle.fontSize,
        fontStyle: parentStyle.textStyle.fontStyle,
        fontWeight: parentStyle.textStyle.fontWeight,
        decoration: parentStyle.textStyle.decoration);

    isDropCaps = parentStyle.isDropCaps;

    return this;
  }

  void getDropCaps(XmlNode element) {
    // The check for line-height is a hack; but makes the chapter starts look better in The Strange Case of the Alchemist's Daughter.
    String? floatValue = _parser.getStringAttribute(element, this, "float");
    String? lineHeight = _parser.getStringAttribute(element, this, "line-height");

    if ((floatValue != null && floatValue == "left") ||  (lineHeight != null && lineHeight == "0em")) {
      isDropCaps = true;
    }
  }

  void getTextStyle(XmlNode element) {
    ReadingProgress progress = GetIt.instance.get<ReadingProgress>();

    final String? fontFamily = _parser.getFontAttribute(element, this, "font-family")?.replaceAll('"', '');
    final double? fontSize   = _parser.getFontSize(element, this, "font-size", progress.fontSize.toDouble());
    final String? fontStyle  = _parser.getStringAttribute(element, this, "font-style");
    final String? fontWeight = _parser.getStringAttribute(element, this, "font-weight");
    final String? fontDecoration  = _parser.getStringAttribute(element, this, "text-decoration");

    textStyle = textStyle.copyWith(
      color: Colors.black,
      decoration: switch (fontDecoration) {
        "underline"    => TextDecoration.underline,
        "line-through" => TextDecoration.lineThrough,
                     _ => textStyle.decoration,
      },
      fontFamily: fontFamily ?? textStyle.fontFamily,
      fontSize:   fontSize ?? textStyle.fontSize,
      fontStyle:  fontStyle == "italic" ? FontStyle.italic : textStyle.fontStyle,
      fontWeight: fontWeight != null ? _parser.getFontWeight(fontWeight) : textStyle.fontWeight,
    );
  }

  @override
  Style parseElement({required XmlNode element, Style? parentStyle}) {
    addSelectors(element);
    addDeclarations(_parser, element);

    if (parentStyle != null) {
      copyWith(parentStyle as ElementStyle);
    }

    getTextStyle(element);
    getDropCaps(element);

    return this;
  }

  @override
  String toString() {
    String result = '{ ';

    if (textStyle.fontSize != null) {
      result += 'font-size: ${textStyle.fontSize}, ';
    }

    if (textStyle.fontFamily != null) {
      result += 'font-family: ${textStyle.fontFamily}, ';
    }

    if (textStyle.fontWeight != null) {
      result += 'font-weight: ${textStyle.fontWeight}, ';
    }

    if (textStyle.fontStyle != null) {
      result += 'font-style: ${textStyle.fontStyle}, ';
    }

    if (textStyle.decoration != null) {
      result += 'decoration: ${textStyle.decoration}, ';
    }

    if (isDropCaps != null) {
      result += 'dropcaps: ${isDropCaps! ? "true" : "false"}';
    }

    result += '}';
    return result;
  }
}