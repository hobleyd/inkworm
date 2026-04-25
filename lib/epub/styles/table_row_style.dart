import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import 'block_style.dart';
import 'element_style.dart';
import 'style.dart';

class TableRowStyle extends BlockStyle {
  Color? backgroundColor;

  TableRowStyle({required super.elementStyle, super.parentStyle});

  static Future<TableRowStyle> getTableRowStyle(XmlElement element, {required ElementStyle elementStyle, Style? parentStyle}) async {
    final TableRowStyle tableRowStyle = TableRowStyle(elementStyle: elementStyle, parentStyle: parentStyle as BlockStyle?);
    await tableRowStyle.parseElement(element: element);
    return tableRowStyle;
  }

  void getBackgroundColor(XmlNode element) {
    addDeclarations(parser, element);

    final String? backgroundColorValue = parser.getStringAttribute(element, this, 'background-color');
    if (backgroundColorValue == null) {
      return;
    }

    final String hex = backgroundColorValue.trim();
    if (!hex.startsWith('#')) {
      return;
    }

    final String normalizedHex = switch (hex.length) {
      4 => hex.split('').map((char) => char == '#' ? '' : '$char$char').join(),
      7 => hex.substring(1),
      _ => '',
    };

    if (normalizedHex.isNotEmpty) {
      backgroundColor = Color(int.parse('FF$normalizedHex', radix: 16));
    }
  }

  @override
  Future<Style> parseElement({required XmlNode element}) async {
    await super.parseElement(element: element);
    getBackgroundColor(element);
    return this;
  }
}
