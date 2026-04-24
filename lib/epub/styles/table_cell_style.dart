import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../parser/css_parser.dart';
import 'block_style.dart';
import 'element_style.dart';
import 'style.dart';
import 'table_style.dart';

class TableCellStyle extends BlockStyle {
  late CssParser _parser;

  TableCellAlignment verticalAlignment = TableCellAlignment.top;
  double cellWidth     = 0;
  double paddingTop    = 0;
  double paddingBottom = 0;
  double paddingLeft   = 0;
  double paddingRight  = 0;

  TableCellStyle({required super.elementStyle, super.parentStyle}) {
    _parser = GetIt.instance.get<CssParser>();
  }

  static Future<TableCellStyle> getTableCellStyle(XmlElement element, {required ElementStyle elementStyle, Style? parentStyle,}) async {
    final TableCellStyle tableCellStyle = TableCellStyle(elementStyle: elementStyle, parentStyle: parentStyle as BlockStyle?,);
    await tableCellStyle.parseElement(element: element);
    return tableCellStyle;
  }

  void getVerticalAlignment(XmlNode element) {
    final String? align = parser.getStringAttribute(element, this, 'vertical-align');
    verticalAlignment = switch (align) {
      'bottom' => TableCellAlignment.bottom,
      'middle' => TableCellAlignment.middle,
            _  => TableCellAlignment.top,
    };
  }

  Future<void> getPadding(XmlNode element) async {
    String? topPaddingString;
    String? bottomPaddingString;
    String? leftPaddingString;
    String? rightPaddingString;

    final String? padding = parser.getStringAttribute(element, this, 'padding');
    if (padding != null) {
      final List<String> parts = padding.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

      if (parts.length == 1) {
        topPaddingString = parts[0];
        rightPaddingString = parts[0];
        bottomPaddingString = parts[0];
        leftPaddingString = parts[0];
      } else if (parts.length == 2) {
        topPaddingString = parts[0];
        bottomPaddingString = parts[0];
        leftPaddingString = parts[1];
        rightPaddingString = parts[1];
      } else if (parts.length == 3) {
        topPaddingString = parts[0];
        leftPaddingString = parts[1];
        rightPaddingString = parts[1];
        bottomPaddingString = parts[2];
      } else if (parts.length == 4) {
        topPaddingString = parts[0];
        rightPaddingString = parts[1];
        bottomPaddingString = parts[2];
        leftPaddingString = parts[3];
      }
    }

    leftPaddingString   = parser.getStringAttribute(element, this, 'padding-left')   ?? leftPaddingString;
    rightPaddingString  = parser.getStringAttribute(element, this, 'padding-right')  ?? rightPaddingString;
    topPaddingString    = parser.getStringAttribute(element, this, 'padding-top')    ?? topPaddingString;
    bottomPaddingString = parser.getStringAttribute(element, this, 'padding-bottom') ?? bottomPaddingString;

    if (leftPaddingString != null) {
      paddingLeft = await parser.getFloatFromString(elementStyle.textStyle, leftPaddingString, true) ?? 0;
    }
    if (rightPaddingString != null) {
      paddingRight = await parser.getFloatFromString(elementStyle.textStyle, rightPaddingString, true) ?? 0;
    }
    if (topPaddingString != null) {
      paddingTop = await parser.getFloatFromString(elementStyle.textStyle, topPaddingString, false) ?? 0;
    }
    if (bottomPaddingString != null) {
      paddingBottom = await parser.getFloatFromString(elementStyle.textStyle, bottomPaddingString, false) ?? 0;
    }
  }

  void getWidth(XmlNode element, TableStyle tableStyle) {
    final String? width = _parser.getStringAttribute(element, this, "width");
    cellWidth = width != null ? _parser.parseFloatCssValue(width, tableStyle.tableWidth) : 0;
  }

  @override
  Future<Style> parseElement({required XmlNode element}) async {
    await super.parseElement(element: element);

    getVerticalAlignment(element);
    await getPadding(element);

    return this;
  }

  @override
  TableCellStyle copyWith({double? topMargin, double? bottomMargin}) {
    final TableCellStyle style = TableCellStyle(elementStyle: elementStyle);

    style.leftMargin = leftMargin;
    style.rightMargin = rightMargin;
    style.topMargin = topMargin ?? this.topMargin;
    style.bottomMargin = bottomMargin ?? this.bottomMargin;

    style.blockMarginEnd = blockMarginEnd;
    style.blockMarginStart = blockMarginStart;
    style.inlineMarginEnd = inlineMarginEnd;
    style.inlineMarginStart = inlineMarginStart;

    style.width = width;
    style.leftIndent = leftIndent;
    style.lineHeightMultiplier = lineHeightMultiplier;
    style.alignment = alignment;

    style.maxHeight = maxHeight;
    style.maxWidth = maxWidth;
    style.display = display;

    style.ignoreVerticalMargins = ignoreVerticalMargins;
    style.verticalAlignment = verticalAlignment;
    style.paddingTop = paddingTop;
    style.paddingBottom = paddingBottom;
    style.paddingLeft = paddingLeft;
    style.paddingRight = paddingRight;

    return style;
  }
}
