import 'package:inkworm/epub/content/paragraph_break.dart';

import '../../elements/line_element.dart';
import '../../styles/table_style.dart';
import '../html_content.dart';
import '../image_content.dart';
import '../line_break.dart';
import 'table_cell.dart';
import 'table_row.dart';

class TableContent extends HtmlContent {
  // Each List item is a Table row, with the contents of each column indexed by id.
  final List<TableRow> rows = [];
  final TableStyle tableStyle;

  @override
  Iterable<LineElement> get elements => throw UnimplementedError;

  TableContent({required super.blockStyle, required super.elementStyle, required super.width, required super.height, required this.tableStyle});

  void calculateColumnWidths() {
    if (rows.isEmpty) return;

    // Single pass: track whether each column has a consistent width and collect cells.
    final Map<int, double?> columnWidths = {};  // null = variable (conflicting widths seen)
    final Map<int, List<TableCell>> cellsPerColumn = {};

    for (final row in rows) {
      for (final MapEntry(:key, :value) in row.entries) {
        cellsPerColumn.putIfAbsent(key, () => []).add(value);

        for (final content in value.contents) {
          if (content is ParagraphBreak || content is LineBreak) continue;

          final double contentWidth = content is ImageContent ? content.requiredWidth : content.width;
          if (!columnWidths.containsKey(key)) {
            columnWidths[key] = contentWidth;               // First width seen for this column.
          } else if (columnWidths[key] != contentWidth) {
            columnWidths[key] = null;                       // Conflicting width — mark as variable.
            break;
            // TODO: TextContent doesn't have a width at this point as we are not at the rendering stage. Need to think about this; may not
            // matter given text content is unlikely to have a consistent width.
          }
        }
      }
    }

    // Ensure columns with no non-break content are represented.
    for (final key in cellsPerColumn.keys) {
      columnWidths.putIfAbsent(key, () => null);
    }

    final double    fixedTotal = columnWidths.values.whereType<double>().fold(0.0, (a, b) => a + b);
    final int    variableCount = columnWidths.values.where((w) => w == null).length;
    final double variableWidth = variableCount > 0 ? (tableStyle.tableWidth - fixedTotal) / variableCount : 0.0;

    for (final MapEntry(:key, :value) in columnWidths.entries) {
      final double columnWidth = value ?? variableWidth;
      for (final cell in cellsPerColumn[key] ?? const <TableCell>[]) {
        cell.width = columnWidth;
      }
    }
  }

  // Called when the table is complete to calculate column widths etc
  void complete() {
    if (tableStyle.dynamicTableColumns) {
      calculateColumnWidths();
    } else {
      scaleFixedColumns();
    }
    for (final row in rows) {
      row.syncWidth();
    }
  }

  // For fixed layout, proportionally scale column widths down if they exceed the table width.
  void scaleFixedColumns() {
    for (final row in rows) {
      final double totalWidth = row.entries.fold(0.0, (sum, e) => sum + e.value.width);
      if (totalWidth <= tableStyle.tableWidth || totalWidth == 0) continue;

      final double scale = tableStyle.tableWidth / totalWidth;
      for (final entry in row.entries) {
        entry.value.width = entry.value.width * scale;
      }
    }
  }

  @override
  String toString() {
    return '$rows';
  }
}
