import 'package:inkworm/epub/elements/line_element.dart';

import '../html_content.dart';
import '../../styles/table_cell_style.dart';
import '../../styles/table_style.dart';

// ignore: must_be_immutable
class TableCell extends HtmlContent {
  double _width;
  final List<HtmlContent> _cellContents = [];

  // ignore: use_super_parameters
  TableCell({required super.blockStyle, required super.elementStyle, required super.height, required double width}) : _width = width, super(width: width);

  List<HtmlContent> get contents => _cellContents;

  @override
  double get width => _width;

  TableCellAlignment get verticalAlignment => (blockStyle as TableCellStyle).verticalAlignment;
  double get paddingTop    => (blockStyle as TableCellStyle).paddingTop;
  double get paddingBottom => (blockStyle as TableCellStyle).paddingBottom;
  double get paddingLeft   => (blockStyle as TableCellStyle).paddingLeft;
  double get paddingRight  => (blockStyle as TableCellStyle).paddingRight;

  set width(double value) {
    _width = value;
  }

  @override
  // TODO: implement elements
  Iterable<LineElement> get elements => throw UnimplementedError();

  void addContents(List<HtmlContent> contents) {
    _cellContents.addAll(contents);
  }

  @override
  String toString() {
    return '$_cellContents';
  }
}
