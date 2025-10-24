import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../parser/css_parser.dart';
import 'style.dart';

class ElementStyle extends Style {
  late CssParser _parser;
  late TextStyle textStyle;

  bool isDropCaps = false;

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

  ElementStyle(XmlElement element) {
    _parser = GetIt.instance.get<CssParser>();

    parseElement(element);
  }

  void getDropCaps(XmlElement element) {
    // The check for line-height is a hack; but makes the chapter starts look better in The Strange Case of the Alchemist's Daughter.
    isDropCaps = _parser.getStringAttribute(element, "float", "no") == "left" || _parser.getStringAttribute(element, "line-height", "") == "0em";
  }

  void getTextStyle(XmlElement element) {
    final String fontFamily = _parser.getStringAttribute(element, "font-family", "");
    final String fontStyle  = _parser.getStringAttribute(element, "font-style", "normal");
    final String fontWeight = _parser.getStringAttribute(element, "font-weight", "normal");
    final String fontDecoration  = _parser.getStringAttribute(element, "text-decoration", "normal");

    textStyle = TextStyle(
      decoration: switch (fontDecoration) {
        "underline" => TextDecoration.underline,
        "line-through" => TextDecoration.lineThrough,
        _ => TextDecoration.none,
      },
      fontFamily: fontFamily,
      fontSize: 12, // TODO: drive from config when created.
      fontStyle: fontStyle == "italic" ? FontStyle.italic : FontStyle.normal,
      fontWeight: fontWeight.startsWith("bold") ? FontWeight.w700 : FontWeight.w400,

    );
  }

  @override
  Style parseElement(XmlElement element) {
    getTextStyle(element);
    getDropCaps(element);

    return this;
  }

  @override
  String toString() {
    return 'FS:${textStyle.fontSize}|FF:${textStyle.fontFamily}|B:${textStyle.fontWeight}|I:${textStyle.fontStyle}|VA:${textStyle.decoration}${isDropCaps ? "|DROPCAPS" : ""}';
  }
}