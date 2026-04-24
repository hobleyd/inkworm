import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../content/paragraph_break.dart';
import '../content/table/table_cell.dart';
import '../content/table/table_content.dart';
import '../content/table/table_row.dart';
import '../parser/extensions.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import '../styles/table_cell_style.dart';
import '../styles/table_style.dart';
import 'html_handler.dart';

class TableHandler extends HtmlHandler {
  TableHandler() {
    HtmlHandler.registerHandler('table', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    final XmlElement element = node as XmlElement;

    final ElementStyle elementStyle = await ElementStyle.getElementStyle(element, parentElementStyle);
    final BlockStyle     blockStyle = await   BlockStyle.getBlockStyle(element, elementStyle: elementStyle, parentStyle: parentBlockStyle,);
    final TableStyle     tableStyle = await   TableStyle.getTableStyle(element);

    if (blockStyle.display == 'none') {
      return [];
    }

    final List<HtmlContent> elements = [
      ParagraphBreak(blockStyle: blockStyle.copyWith(bottomMargin: 0), elementStyle: elementStyle, width: 0, height: 0,),
    ];

    // We need to get the table contents first, then use this to set with column widths and any other relevant styling.
    TableContent contents = TableContent(blockStyle: blockStyle, elementStyle: elementStyle, tableStyle: tableStyle, width: tableStyle.tableWidth, height: 0);
    for (var row in node.findAllElements('tr').toList()) {
      TableRow tableRow = TableRow(blockStyle: blockStyle, elementStyle: elementStyle, height: 0, width: 0);

      final List<XmlElement> columns = row.children.whereType<XmlElement>().where((child) => child.localName == 'td' || child.localName == 'th').toList();
      for (int i = 0; i < columns.length; i++) {
        final ElementStyle cellElementStyle = await   ElementStyle.getElementStyle(columns[i], elementStyle);
        final TableCellStyle cellBlockStyle = await TableCellStyle.getTableCellStyle(columns[i], elementStyle: cellElementStyle, parentStyle: blockStyle,);

        if (!tableStyle.dynamicTableColumns) {
          cellBlockStyle.getWidth(columns[i], tableStyle);
          if (cellBlockStyle.cellWidth == 0) {
            // Fallback to the header widths if we miss one in the table.
            cellBlockStyle.cellWidth = contents.rows.first[i]?.width ?? 0;
          }
        }
        TableCell tableCell = TableCell(blockStyle: cellBlockStyle, elementStyle: cellElementStyle, height: 0, width: cellBlockStyle.cellWidth);

        final List<HtmlContent>? cellContents = await columns[i].handler?.processElement(node: columns[i], parentBlockStyle: cellBlockStyle, parentElementStyle: cellElementStyle,);
        if (cellContents?.isNotEmpty ?? false) {
          tableCell.addContents(cellContents!);
        }
        tableRow.addContent(i, tableCell);
      }

      contents.rows.add(tableRow);
    }
    contents.complete();

    elements.add(contents);
    elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(topMargin: 0), elementStyle: elementStyle, width: 0, height: 0,),);

    return elements;
  }
}
