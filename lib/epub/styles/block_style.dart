import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../parser/css_parser.dart';
import 'element_style.dart';
import 'style.dart';

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
  String alignment = "justify";

  // Table properties
  Map<int, BlockStyle> tableColumns = {};
  String tableLayout = "";
  String tableOverflow = "";
  String tableWhitespace = "";

  bool ignoreVerticalMargins = false;

  BlockStyle(XmlElement element) {
    _parser = GetIt.instance.get<CssParser>();

    parseElement(element);
  }

  void getAlignment(XmlElement element) {
    alignment = _parser.getStringAttribute(element, "text-align", "justify");
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

  void getTableStyles(XmlElement element) {
    // TODO: should really support text-overflow: ellipsis; if I am supporting overflow.
    tableWhitespace = _parser.getStringAttribute(element,  "white-space",  "wrap");
    tableOverflow   = _parser.getStringAttribute(element,  "overflow",     "");
    tableLayout     = _parser.getStringAttribute(element,  "table-layout", "fixed");
    width           = _parser.getPercentAttribute(element, "width",        "100%");
  }

  @override
  Style parseElement(XmlElement element) {
    elementStyle = ElementStyle(element);

    getAlignment(element);
    getLineIndent(element);
    getLineHeightMultiplier(element);
    getMargins(element);
    getTableStyles(element);

    return this;
  }
}