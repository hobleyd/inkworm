import 'dart:ui';

import 'package:inkworm/epub/content/html_content.dart';

import 'line_element.dart';

class TableRowBreak extends LineElement {
  TableRowBreak({required super.width, required super.height});

  @override
  // TODO: implement element
  HtmlContent get element => throw UnimplementedError();

  @override
  void paint(Canvas c, double height, double xPos, double yPos) {
    // TODO: implement paint
  }

}