import '../elements/line_element.dart';
import '../elements/table_row_break.dart';
import '../styles/table_style.dart';
import 'html_content.dart';

class TableContent extends HtmlContent {
  // Each List item is a Table row, with the contents of each column indexed by id.
  final List<Map<int, List<HtmlContent>>> contentByColumn = [];
  final TableStyle tableStyle;

  @override
  Iterable<LineElement> get elements => contentByColumn
      .expand((map) => map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      .expand((entry) => entry.value)
      .expand((htmlContent) => [...htmlContent.elements, TableRowBreak(width: tableStyle.tableWidth, height: 0)])
      .toList();

  TableContent({required super.blockStyle, required super.elementStyle, required super.width, required super.height, required this.tableStyle});

  void addContent(int column, List<HtmlContent> contents) {
    contentByColumn.add({column: contents});
  }

  void calculateColumnWidths() {
    if (contentByColumn.isNotEmpty) {
      // Collect all distinct widths seen per column across all rows.
      final Map<int, Set<double>> widthsPerColumn = {};

      for (final row in contentByColumn) {
        for (final MapEntry(:key, :value) in row.entries) {
          widthsPerColumn.putIfAbsent(key, Set.new);
          for (final content in value) {
            widthsPerColumn[key]!.add(content.width);
          }
        }
      }

      // A column is "fixed" only if every piece of content in it shares exactly one width value.
      for (final MapEntry(:key, :value) in widthsPerColumn.entries) {
        tableStyle.tableColumnWidths[key] = value.length == 1 ? value.single : null;
      }

      // Distribute the remainder of tableStyle.tableWidth across variable columns.
      final double fixedTotal = tableStyle.tableColumnWidths.values.whereType<double>().fold(0, (a, b) => a + b);
      final int variableCount = tableStyle.tableColumnWidths.values.where((w) => w == null).length;
      final double variableWidth = variableCount > 0
          ? (tableStyle.tableWidth - fixedTotal) / variableCount
          : 0;

      for (final MapEntry(:key, :value) in widthsPerColumn.entries) {
        tableStyle.tableColumnWidths[key] = value.length == 1 ? value.single : variableWidth;
      }
    }
  }

  // Called when the table is complete to calculate column widths etc
  void complete() {
    if (tableStyle.dynamicTableColumns) {
      calculateColumnWidths();
    }

  }

  @override
  String toString() {
    return '$contentByColumn';
  }
}
