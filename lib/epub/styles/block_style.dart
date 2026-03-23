import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../../models/page_size.dart';
import '../parser/css_parser.dart';
import 'element_style.dart';
import 'style.dart';

enum LineAlignment { left, right, centre, justify, none }

class BlockStyle extends Style {
  late CssParser _parser;
  ElementStyle elementStyle;
  Style? parentStyle;

  String? display;

  // Margins
  double? leftMargin;
  double? rightMargin;
  double? topMargin;
  double? bottomMargin;

  double? blockMarginEnd;
  double? blockMarginStart;
  double? inlineMarginEnd;
  double? inlineMarginStart;

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

  double get marginBottom => (bottomMargin ?? 0) + (blockMarginEnd ?? 0);
  double get marginTop => (topMargin ?? 0) + (blockMarginStart ?? 0);

  double get marginLeft => (leftMargin ?? 0) + (inlineMarginStart ?? 0);
  double get marginRight => (rightMargin ?? 0) + (inlineMarginEnd ?? 0);

  BlockStyle({required this.elementStyle, this.parentStyle}) {
    _parser = GetIt.instance.get<CssParser>();
  }

  BlockStyle copyFrom(BlockStyle parent) {
    alignment             = parent.alignment;
    leftIndent            = parent.leftIndent;
    ignoreVerticalMargins = parent.ignoreVerticalMargins;
    inlineMarginStart     = parent.inlineMarginStart;
    inlineMarginEnd       = parent.inlineMarginEnd;

    return this;
  }

  BlockStyle copyWith({double? topMargin, double? bottomMargin}) {
    BlockStyle style = BlockStyle(elementStyle: elementStyle);

    style.leftMargin   = leftMargin;
    style.rightMargin  = rightMargin;
    style.topMargin    = topMargin ?? this.topMargin;
    style.bottomMargin = bottomMargin ?? this.bottomMargin;

    style.blockMarginEnd    = blockMarginEnd;
    style.blockMarginStart  = blockMarginStart;
    style.inlineMarginEnd   = inlineMarginEnd;
    style.inlineMarginStart = inlineMarginStart;

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
    String? alignAttribute = element.getAttribute('align');
    if (alignAttribute != null) {
      if (alignAttribute == 'center') {
        alignment = LineAlignment.centre;
        return;
      }
    }

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

  Future<void> getLineHeightMultiplier(XmlNode element) async {
    // TODO: Should we support this?
    if (false) {
      lineHeightMultiplier = await _parser.getFloatAttribute(element, "line-height", elementStyle, false) ?? lineHeightMultiplier;
    }
    lineHeightMultiplier = 1;
  }

  Future<void> getLineIndent(XmlNode element) async {
    leftIndent = await _parser.getFloatAttribute(element, "text-indent", elementStyle, true) ?? leftIndent;
  }

  Future<void> getMargins(XmlNode element) async {
    String? leftMarginString;
    String? rightMarginString;
    String? topMarginString;
    String? bottomMarginString;

    String? margins = _parser.getStringAttribute(element, this, "margin");
    if (margins != null) {
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

    // The more specific options here take precedence!
    leftMarginString   = _parser.getStringAttribute(element, this, "margin-left")   ?? leftMarginString;
    rightMarginString  = _parser.getStringAttribute(element, this, "margin-right")  ?? rightMarginString;
    topMarginString    = _parser.getStringAttribute(element, this, "margin-top")    ?? topMarginString;
    bottomMarginString = _parser.getStringAttribute(element, this, "margin-bottom") ?? bottomMarginString;

    if (leftMarginString != null) {
      if (leftMarginString.endsWith('%')) {
        PageSize size = GetIt.instance.get<PageSize>();
        leftMargin = _parser.parseFloatCssValue(leftMarginString, size.canvasWidth);
      } else {
        leftMargin = await _parser.getFloatFromString(elementStyle.textStyle, leftMarginString, true);
      }
    }

    if (rightMarginString != null) {
      if (rightMarginString.endsWith('%')) {
        PageSize size = GetIt.instance.get<PageSize>();
        rightMargin = _parser.parseFloatCssValue(rightMarginString, size.canvasWidth);
      } else {
        rightMargin = await _parser.getFloatFromString(elementStyle.textStyle, rightMarginString, true);
      }
    }

    if (topMarginString != null) {
      if (topMarginString.endsWith('%')) {
        PageSize size = GetIt.instance.get<PageSize>();
        topMargin = _parser.parseFloatCssValue(topMarginString, size.canvasHeight);
      } else {
        topMargin = await _parser.getFloatFromString(elementStyle.textStyle, topMarginString, true);
      }
    }

    if (bottomMarginString != null) {
      if (bottomMarginString.endsWith('%')) {
        PageSize size = GetIt.instance.get<PageSize>();
        bottomMargin = _parser.parseFloatCssValue(bottomMarginString, size.canvasHeight);
      } else {
        bottomMargin = await _parser.getFloatFromString(elementStyle.textStyle, bottomMarginString, true);
      }
    }

    // Now check for the other kind of margin. Thanks CSS committee.
    String blockMarginEndString = _parser.getStringAttribute(element, this, "margin-block-end") ?? "";
    String blockMarginStartString = _parser.getStringAttribute(element, this, "margin-block-start") ?? "";
    String inlineMarginEndString = _parser.getStringAttribute(element, this, "margin-inline-end") ?? "";
    String inlineMarginStartString = _parser.getStringAttribute(element, this, "margin-inline-start") ?? "";

    if (blockMarginEndString.isNotEmpty)    blockMarginEnd    = await _parser.getFloatFromString(elementStyle.textStyle, blockMarginEndString, false);
    if (blockMarginStartString.isNotEmpty)  blockMarginStart  = await _parser.getFloatFromString(elementStyle.textStyle, blockMarginStartString, false);
    if (inlineMarginEndString.isNotEmpty)   inlineMarginEnd   = await _parser.getFloatFromString(elementStyle.textStyle, inlineMarginEndString, false);
    if (inlineMarginStartString.isNotEmpty) inlineMarginStart = await _parser.getFloatFromString(elementStyle.textStyle, inlineMarginStartString, false);
  }

  void getMax(XmlNode element) {
    // TODO: decide on a default size, for Cover images 100% is probably correct.
    maxHeight ??= _parser.getPercentAttribute(element,  this, "max-height");
    maxWidth  ??= _parser.getPercentAttribute(element,  this, "max-width");
    maxWidth  ??= _parser.getPercentAttribute(element,  this, "width");
  }

  void getTableStyles(XmlNode element) {
    // TODO: should really support text-overflow: ellipsis; if I am supporting overflow.
    tableWhitespace = _parser.getStringAttribute(element,  this, "white-space") ?? tableWhitespace;
    tableOverflow   = _parser.getStringAttribute(element,  this, "overflow") ?? tableOverflow;
    tableLayout     = _parser.getStringAttribute(element,  this, "table-layout") ?? tableLayout;
    width           = _parser.getPercentAttribute(element, this, "width") ?? width;
  }

  @override
  Future <Style> parseElement({required XmlNode element}) async {
    // TODO: Hideous hack. Fix, please. Should ElementStyle and BlockStyle inherit off the same base object?
    selectors = elementStyle.selectors;
    declarations = elementStyle.declarations;

    if (parentStyle != null) {
      copyFrom(parentStyle as BlockStyle);
    }

    await getLineIndent(element);
    getAlignment(element); // Ensure this happens after getting the LineIndent.
    getDisplay(element);
    getLineHeightMultiplier(element);
    await getMargins(element);
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

    if (blockMarginStart != null) {
      result += 'block-margin-start: $blockMarginStart, ';
    }

    if (blockMarginEnd != null) {
      result += 'block-margin-end: $blockMarginEnd, ';
    }

    if (inlineMarginStart != null) {
      result += 'inline-margin-start: $inlineMarginStart, ';
    }

    if (inlineMarginEnd != null) {
      result += 'inline-margin-end: $inlineMarginEnd, ';
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