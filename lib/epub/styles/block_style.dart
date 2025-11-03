import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/elements/line.dart';
import 'package:xml/xml.dart';

import '../parser/css_parser.dart';
import '../parser/extensions.dart';
import 'element_style.dart';
import 'style.dart';

enum LineAlignment { left, right, centre, justify }

class BlockStyle extends Style {
  late CssParser _parser;
  late ElementStyle elementStyle;

  // Margins
  double leftMargin = 0;
  double rightMargin = 0;
  double topMargin = 0;
  double bottomMargin = 0;

  // Line related
  double width = 0;
  double leftIndent = 0;
  double lineHeightMultiplier = 0;
  LineAlignment alignment = LineAlignment.justify;

  double maxHeight = 0;
  double maxWidth = 0;

  // Table properties
  Map<int, BlockStyle> tableColumns = {};
  String tableLayout = "";
  String tableOverflow = "";
  String tableWhitespace = "";

  bool ignoreVerticalMargins = false;

  BlockStyle() {
    _parser = GetIt.instance.get<CssParser>();
  }

  void getAlignment(XmlElement element) {
    alignment = switch(_parser.getStringAttribute(element, "text-align", "justify")) {
      "center" || "centre" => LineAlignment.centre,
      "left"               => LineAlignment.left,
      "right"              => LineAlignment.right,
      _                    => LineAlignment.justify,
    };
  }

  void getLineHeightMultiplier(XmlElement element) {
    // TODO: Should we support this?
    if (false) {
      lineHeightMultiplier = _parser.getFloatAttribute(element, "line-height", "1em", elementStyle.textStyle, false);
    }
    lineHeightMultiplier = 1;
  }

  void getLineIndent(XmlElement element) {
    leftIndent = _parser.getFloatAttribute(element, "text-indent", "1.5em", elementStyle.textStyle, true);
  }

  void getMargins(XmlElement element) {
    String leftMarginString   = "";
    String rightMarginString  = "";
    String topMarginString    = "";
    String bottomMarginString = "";

    String? margins = _parser.getStringAttribute(element, "margin", "");
    if (margins.isEmpty) {
      leftMarginString   = _parser.getStringAttribute(element, "margin-left", "");
      rightMarginString  = _parser.getStringAttribute(element, "margin-right", "");
      topMarginString    = _parser.getStringAttribute(element, "margin-top", "");
      bottomMarginString = _parser.getStringAttribute(element, "margin-bottom", "");
    } else {
      List<String> parts = margins.split(RegExp(r'\s'));

      if (parts.length == 1) {
        bottomMarginString = parts[0];
        topMarginString    = parts[0];
        leftMarginString   = parts[0];
        rightMarginString  = parts[0];
      } else if (parts.length == 2) {
        topMarginString    = parts[0];
        bottomMarginString = parts[0];
        leftMarginString   = parts[1];
        rightMarginString  = parts[1];
      } else if (parts.length == 3) {
        topMarginString    = parts[0];
        leftMarginString   = parts[1];
        rightMarginString  = parts[1];
        bottomMarginString = parts[2];
      } else if (parts.length == 4) {
        topMarginString    = parts[0];
        rightMarginString  = parts[1];
        bottomMarginString = parts[2];
        leftMarginString   = parts[3];
      }

      leftMargin   = _parser.getFloatFromString(elementStyle.textStyle, leftMarginString,   "0px", true);
      rightMargin  = _parser.getFloatFromString(elementStyle.textStyle, rightMarginString,  "0px", true);
      topMargin    = _parser.getFloatFromString(elementStyle.textStyle, topMarginString,    "0px", false);
      bottomMargin = _parser.getFloatFromString(elementStyle.textStyle, bottomMarginString, "0px", false);
    }
  }

  void getMax(XmlElement element) {
    // TODO: decide on a default size, for Cover images 100% is probably correct.
    maxHeight = _parser.getPercentAttribute(element,  "max-height",  "100%");
    maxWidth  = _parser.getPercentAttribute(element,  "max-width",  "100%");

    if (maxWidth == 1) {
      alignment = LineAlignment.centre;
    }
  }

  void getTableStyles(XmlElement element) {
    // TODO: should really support text-overflow: ellipsis; if I am supporting overflow.
    tableWhitespace = _parser.getStringAttribute(element,  "white-space",  "wrap");
    tableOverflow   = _parser.getStringAttribute(element,  "overflow",     "");
    tableLayout     = _parser.getStringAttribute(element,  "table-layout", "fixed");
    width           = _parser.getPercentAttribute(element, "width",        "100%");
  }

  @override
  Style parseElement(XmlElement element) {
    elementStyle = ElementStyle();
    elementStyle.parseElement(element);

    debugPrint('decls: ${element.localName}${element.attributes}: ${_parser.getCSSDeclarations(element)}');
    CssDeclarations? decls = _parser.getCSSDeclarations(element);
    getAlignment(element);
    getLineIndent(element);
    getLineHeightMultiplier(element);
    getMargins(element);
    getMax(element);
    getTableStyles(element);

    return this;
  }
}