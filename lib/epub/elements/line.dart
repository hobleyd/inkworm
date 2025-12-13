import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../styles/block_style.dart';
import 'separators/non_breaking_space_separator.dart';
import 'separators/separator.dart';
import 'separators/space_separator.dart';
import 'line_element.dart';

class Line {
  LineAlignment alignment = LineAlignment.justify;

  double dropCapsIndent = 0;
  double height = 0;
  double leftIndent = 0;
  double rightIndent = 0;
  double textIndent = 0;
  double yPos = 0;

  List<LineElement> elements = [];

  int    get separators      => elements.whereType<Separator>().length;
  double get bottomYPosition => yPos + height;
  double get leftIndents     => leftIndent + textIndent + dropCapsIndent;
  double get width           => leftIndents + elements.fold(0, (sum, item) => sum + item.width);

  Line({required this.yPos, required BlockStyle blockStyle}) {
    PageSize size = GetIt.instance.get<PageSize>();

    leftIndent = size.leftIndent;
    rightIndent = size.rightIndent;

    alignment = blockStyle.alignment != null ? blockStyle.alignment! : LineAlignment.justify;
  }

  void addElement(LineElement e) {
    // We don't add multiple spaces together unless they are non-breaking.
    if (e is SpaceSeparator) {
      if (elements.isEmpty) {
        return;
      } else if (elements.last is SpaceSeparator || elements.last is NonBreakingSpaceSeparator) {
        return;
      }
    }

    if (!(e.element.elementStyle.isDropCaps ?? false)) {
      // Only adjust the line height if this is not a dropcaps element. For obvious reasons. Given the use of dropcaps I can't
      // imagine it will be possible that this is the only thing on the line. On the other hand. HTML. Sigh.
      height = max(height, e.height);
    }

    elements.add(e);
  }

  void calculateSeparatorWidth() {
    PageSize size = GetIt.instance.get<PageSize>();
    if (alignment == LineAlignment.justify) {
      double additionalSpaceWidth = (size.canvasWidth - rightIndent - width) / separators;

      bool printedSpaces = false;
      for (LineElement e in elements) {
        if (e is Separator) {
          if (!printedSpaces) {
            printedSpaces = true;
          }
          e.width = e.width + additionalSpaceWidth;
        }
      }
    } else if (alignment == LineAlignment.centre) {
      // Adjust left margin now we know the width of the words in the line.
      double margin = (size.canvasWidth - width) / 2;
      leftIndent = margin;
      rightIndent = size.canvasWidth - margin;
    } else {
      if (alignment == LineAlignment.right) {
        leftIndent = rightIndent - width;
        textIndent = 0;
      }
    }
  }

  void completeLine() {
    if (elements.isNotEmpty) {
      while (elements.last is SpaceSeparator) {
        elements.removeLast();
      }

      calculateSeparatorWidth();
    }
  }

  void completeParagraph() {
    // Don't justify the last line in a paragraph.
    if (alignment == LineAlignment.justify) {
      alignment = LineAlignment.left;
    }
  }

  @override
  String toString() {
    String result = "$yPos: $bottomYPosition: ${alignment.name}: LI: $leftIndent: TI: $textIndent: DCI: $dropCapsIndent: ";
    for (var el in elements) {
      result += '$el';
    }

    return result;
  }

  bool willFitHeight(LineElement e) {
    PageSize size = GetIt.instance.get<PageSize>();
    return (yPos + e.height) <= size.canvasHeight;
  }

  bool willFitWidth(LineElement e) {
    PageSize size = GetIt.instance.get<PageSize>();
    return (width + e.width) <= (size.canvasWidth - rightIndent);
  }
}