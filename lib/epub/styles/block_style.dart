import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../parser/css_parser.dart';
import 'element_style.dart';
import 'style.dart';

enum LineAlignment { left, right, centre, justify, none }

class BlockStyle extends Style {
  late CssParser _parser;
  ElementStyle elementStyle;

  // Margins
  double? leftMargin;
  double? rightMargin;
  double? topMargin;
  double? bottomMargin;

  // Line related
  double? width;
  double? leftIndent;
  double? lineHeightMultiplier;
  LineAlignment? alignment;

  double? maxHeight;
  double? maxWidth;

  // Table properties
  Map<int, BlockStyle> tableColumns = {};
  String? tableLayout;
  String? tableOverflow;
  String? tableWhitespace;

  bool ignoreVerticalMargins = false;

  BlockStyle({required this.elementStyle}) {
    _parser = GetIt.instance.get<CssParser>();
  }

  BlockStyle copyWith(BlockStyle parent) {
    leftMargin   = parent.leftMargin;
    rightMargin  = parent.leftMargin;
    topMargin    = parent.leftMargin;
    bottomMargin = parent.leftMargin;

    width = parent.width;
    leftIndent = parent.leftIndent;
    lineHeightMultiplier = parent.lineHeightMultiplier;
    alignment = parent.alignment;

    maxHeight = parent.maxHeight;
    maxWidth = parent.maxWidth;

    tableColumns.addAll(parent.tableColumns);
    tableLayout = parent.tableLayout;
    tableOverflow = parent.tableOverflow;
    tableWhitespace = parent.tableWhitespace;

    ignoreVerticalMargins = parent.ignoreVerticalMargins;

    return this;
  }


  void getAlignment(XmlNode element) {
    alignment = switch(_parser.getStringAttribute(element, this, "text-align")) {
      "center" || "centre" => LineAlignment.centre,
      "left"               => LineAlignment.left,
      "right"              => LineAlignment.right,
      "justify"            => LineAlignment.justify,
      _                    => alignment,
    };
  }

  void getLineHeightMultiplier(XmlNode element) {
    // TODO: Should we support this?
    if (false) {
      lineHeightMultiplier = _parser.getFloatAttribute(element, "line-height", elementStyle, false) ?? lineHeightMultiplier;
    }
    lineHeightMultiplier = 1;
  }

  void getLineIndent(XmlNode element) {
    leftIndent = _parser.getFloatAttribute(element, "text-indent", elementStyle, true) ?? leftIndent;
  }

  void getMargins(XmlNode element) {
    String? leftMarginString;
    String? rightMarginString;
    String? topMarginString;
    String? bottomMarginString;

    String? margins = _parser.getStringAttribute(element, this, "margin");
    if (margins == null) {
      leftMarginString   = _parser.getStringAttribute(element, this, "margin-left") ?? leftMarginString;
      rightMarginString  = _parser.getStringAttribute(element, this, "margin-right") ?? rightMarginString;
      topMarginString    = _parser.getStringAttribute(element, this, "margin-top") ?? topMarginString;
      bottomMarginString = _parser.getStringAttribute(element, this, "margin-bottom") ?? bottomMarginString;
    } else {
      List<String> parts = margins.split(RegExp(r'\s'));

      if (parts.length == 1) {
        bottomMarginString = parts[0];
        topMarginString = parts[0];
        leftMarginString = parts[0];
        rightMarginString = parts[0];
      } else if (parts.length == 2) {
        topMarginString = parts[0];
        bottomMarginString = parts[0];
        leftMarginString = parts[1];
        rightMarginString = parts[1];
      } else if (parts.length == 3) {
        topMarginString = parts[0];
        leftMarginString = parts[1];
        rightMarginString = parts[1];
        bottomMarginString = parts[2];
      } else if (parts.length == 4) {
        topMarginString = parts[0];
        rightMarginString = parts[1];
        bottomMarginString = parts[2];
        leftMarginString = parts[3];
      }
    }

    if (leftMarginString != null) leftMargin = _parser.getFloatFromString(elementStyle.textStyle, leftMarginString, true);
    if (rightMarginString != null) rightMargin = _parser.getFloatFromString(elementStyle.textStyle, rightMarginString, true);
    if (topMarginString != null) topMargin = _parser.getFloatFromString(elementStyle.textStyle, topMarginString, false);
    if (bottomMarginString != null) bottomMargin = _parser.getFloatFromString(elementStyle.textStyle, bottomMarginString, false);
  }

  void getMax(XmlNode element) {
    // TODO: decide on a default size, for Cover images 100% is probably correct.
    maxHeight = _parser.getPercentAttribute(element,  this, "max-height") ?? maxHeight;
    maxWidth  = _parser.getPercentAttribute(element,  this, "max-width") ?? maxWidth;
  }

  void getTableStyles(XmlNode element) {
    // TODO: should really support text-overflow: ellipsis; if I am supporting overflow.
    tableWhitespace = _parser.getStringAttribute(element,  this, "white-space") ?? tableWhitespace;
    tableOverflow   = _parser.getStringAttribute(element,  this, "overflow") ?? tableOverflow;
    tableLayout     = _parser.getStringAttribute(element,  this, "table-layout") ?? tableLayout;
    width           = _parser.getPercentAttribute(element, this, "width") ?? width;
  }

  @override
  Style parseElement({required XmlNode element, Style? parentStyle}) {
    // TODO: Hideous hack. Fix, please. Should ElementStyle and BlockStyle inherit of the same base object?
    selectors = elementStyle.selectors;
    declarations = elementStyle.declarations;

    if (parentStyle != null) {
      copyWith(parentStyle as BlockStyle);
    }

    getAlignment(element);
    getLineIndent(element);
    getLineHeightMultiplier(element);
    getMargins(element);
    getMax(element);
    getTableStyles(element);

    return this;
  }

  @override
  String toString() {
    String result = '{ ';

    if (leftMargin != null) {
      result += 'margin-left: $leftMargin, ';
    }

    if (rightMargin != null) {
      result += 'margin-right: $rightMargin, ';
    }

    if (topMargin != null) {
      result += 'margin-top: $topMargin, ';
    }

    if (bottomMargin != null) {
      result += 'margin-bottom: $bottomMargin, ';
    }

    if (leftIndent != null) {
      result += 'left-indent: $leftIndent, ';
    }

    if (alignment != null) {
      result += 'alignment: ${alignment?.name}, ';
    }

    if (maxHeight != null) {
      result += 'max-height: $maxHeight, ';
    }

    if (maxWidth != null) {
      result += 'max-width: $maxWidth, ';
    }

    result += '}';

    return result;
  }
}