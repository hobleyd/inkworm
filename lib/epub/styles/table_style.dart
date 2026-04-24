import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../../models/page_size.dart';
import '../parser/css_parser.dart';
import 'style.dart';

enum TableLayout { auto, fixed }
enum TableCellAlignment { top, middle, bottom }

class TableStyle extends Style {
  late CssParser _parser;

  // Table properties
  TableLayout tableLayout = TableLayout.auto;
  double      tableWidth  = 100;

  // Table Columns
  Map<int, double?>             tableColumnWidths = {};

  bool get dynamicTableColumns => tableLayout == TableLayout.auto;

  TableStyle() {
    _parser = GetIt.instance.get<CssParser>();
  }

  static Future<TableStyle> getTableStyle(XmlElement element) async {
    final TableStyle tableStyle = TableStyle();
    await tableStyle.parseElement(element: element);
    return tableStyle;
  }

  void getTableWidth(XmlNode element) {
    PageSize size = GetIt.instance.get<PageSize>();
    final String? width = _parser.getStringAttribute(element, this, "width");
    tableWidth = width != null ? _parser.parseFloatCssValue(width, size.actualWidth) : size.actualWidth;
  }

  void getTableLayout(XmlNode element) {
    tableLayout = switch(_parser.getStringAttribute(element,  this, "table-layout")) {
      'fixed' => TableLayout.fixed,
           _  => TableLayout.auto
    };
  }

  @override
  Future<Style> parseElement({required XmlNode element}) async {
    addSelectors(element);
    addDeclarations(_parser, element);

    getTableLayout(element);
    getTableWidth(element);

    return this;
  }

}
