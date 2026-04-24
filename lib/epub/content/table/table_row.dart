import 'package:inkworm/epub/elements/line_element.dart';

import '../html_content.dart';
import 'table_cell.dart';

class TableRow extends HtmlContent {
  final Map<int, TableCell> row = {};

  TableRow({required super.blockStyle, required super.elementStyle, required super.height, required super.width});

  Iterable<MapEntry<int, TableCell>> get entries => row.entries;

  TableCell? operator[](int i) => row[i];

  @override
  Iterable<LineElement> get elements => throw UnimplementedError();

  void addContent(int column, TableCell cell) {
    row[column] = cell;
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