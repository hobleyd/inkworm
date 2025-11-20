import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../parser/css_parser.dart';
import 'element_style.dart';
import 'style.dart';

enum LineAlignment { left, right, centre, justify, none }

class BlockStyle extends Style {
  late CssParser _parser;
  ElementStyle elementStyle;

  String? display;

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

  double get marginBottom => (bottomMargin ?? 0);
  double get marginTop => (topMargin ?? 0);

  BlockStyle({required this.elementStyle}) {
    _parser = GetIt.instance.get<CssParser>();
  }

  BlockStyle copyFrom(BlockStyle parent) {
    leftMargin   = parent.leftMargin;
    rightMargin  = parent.rightMargin;
    topMargin    = parent.topMargin;
    bottomMargin = parent.bottomMargin;

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

  BlockStyle copyWith({double? topMargin, double? bottomMargin}) {
    BlockStyle style = BlockStyle(elementStyle: elementStyle);

    style.leftMargin   = leftMargin;
    style.rightMargin  = rightMargin;
    style.topMargin    = topMargin ?? this.topMargin;
    style.bottomMargin = bottomMargin ?? this.bottomMargin;

    style.width = width;
    style.leftIndent = leftIndent;
    style.lineHeightMultiplier = lineHeightMultiplier;
    style.alignment = alignment;

    style.maxHeight = maxHeight;
    style.maxWidth = maxWidth;

    style.tableColumns.addAll(tableColumns);
    style.tableLayout = tableLayout;
    style.tableOverflow = tableOverflow;
    style.tableWhitespace = tableWhitespace;

    style.ignoreVerticalMargins = ignoreVerticalMargins;

    return style;
  }

  void getAlignment(XmlNode element) {
    String? alignmentAttribute = _parser.getStringAttribute(element, this, "text-align");
    if (alignmentAttribute == null) {
      // This is another way of centering in CSS.
      String? leftMarginString   = _parser.getStringAttribute(element, this, "margin-left");
      String? rightMarginString  = _parser.getStringAttribute(element, this, "margin-right");

      if (leftMarginString != null && rightMarginString != null) {
        if (leftMarginString == "auto" && rightMarginString == "auto") {
          alignment = LineAlignment.centre;
        }
      }
    } else {
      alignment = switch(alignmentAttribute) {
        "center" || "centre" => LineAlignment.centre,
        "left" => LineAlignment.left,
        "right" => LineAlignment.right,
        "justify" => LineAlignment.justify,
        _ => alignment,
      };
    }

    // TODO: this shouldn't be necessary. Look into this at some point.
    if (alignment == LineAlignment.centre) {
      leftIndent = 0;
    }
  }

  void getDisplay(XmlNode element) {
    // Display is used to determine whether you want to see an element or not. In an interactive web-page
    // this can make sense; but in a book? But none-the-less, I've seen it used!
    display = _parser.getStringAttribute(element, this, "display");
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

  BlockStyle getBottomMarginStyle() {
    BlockStyle style = BlockStyle(elementStyle: elementStyle);
    style.bottomMargin = bottomMargin;

    return style;
  }

  BlockStyle getTopMarginStyle() {
    BlockStyle style = BlockStyle(elementStyle: elementStyle);
    style.topMargin = topMargin;

    return style;
  }

  @override
  Style parseElement({required XmlNode element, Style? parentStyle}) {
    // TODO: Hideous hack. Fix, please. Should ElementStyle and BlockStyle inherit off the same base object?
    selectors = elementStyle.selectors;
    declarations = elementStyle.declarations;

    if (parentStyle != null) {
      copyFrom(parentStyle as BlockStyle);
    }

    getLineIndent(element);
    getAlignment(element); // Ensure this happens after getting the LineIndent.
    getDisplay(element);
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