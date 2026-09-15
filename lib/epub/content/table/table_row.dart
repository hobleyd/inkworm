import 'dart:ui' show Color, Rect;

import '../../../epub/elements/line_element.dart';
import '../../structure/page.dart';
import '../../styles/table_row_style.dart';
import '../html_content.dart';
import 'table_cell.dart';

// TableRow is genuinely mutable: its width is reconciled as cells are added and again once every
// column in the row has been laid out, so it cannot take HtmlContent's immutable contract.
// ignore: must_be_immutable
class TableRow extends HtmlContent {
  late double _width;
  final Map<int, TableCell> row = {};

  TableRow({required super.blockStyle, required super.elementStyle, required super.height, required super.width}) {
    // super.width reads the base field rather than the overridden getter below, which needs _width.
    _width = super.width;
  }

  Iterable<MapEntry<int, TableCell>> get entries => row.entries;
  TableRowStyle get rowStyle => blockStyle as TableRowStyle;
  Color? get backgroundColor => rowStyle.backgroundColor;

  @override
  double get width => _width;

  TableCell? operator[](int i) => row[i];

  @override
  Iterable<LineElement> get elements => throw UnimplementedError();

  void addContent(int column, TableCell cell) {
    row[column] = cell;
    _width += cell.width;
  }

  void syncWidth() {
    _width = entries.fold(0.0, (sum, entry) => sum + entry.value.width);
  }

  void addBackgrounds(Page page, double xPos, double yPos, double rowHeight) {
    if (backgroundColor == null) {
      return;
    }

    page.addBackground(PageBackground(color: backgroundColor!, rect: Rect.fromLTWH(xPos, yPos, width, rowHeight),));
  }

  @override
  String toString() {
    String str = "";

    for (var col in row.keys) {
      str += "[$col] ${row[col]} ";
    }

    return str;
  }
}
