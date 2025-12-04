import 'dart:math';

import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../styles/block_style.dart';
import 'separators/non_breaking_space_separator.dart';
import 'separators/separator.dart';
import 'separators/space_separator.dart';
import 'line_element.dart';

class Line {
  LineAlignment alignment = LineAlignment.justify;
  double yPos = 0;
  double dropCapsIndent = 0;
  double height = 0;
  double leftIndent = 0;
  double rightIndent = 0;
  double textIndent = 0;
  int _separatorCount = 0;
  double _computedWidth = 0;
  double _computedWidthNoSeparators = 0;

  List<LineElement> elements = [];

  double get bottomYPosition => yPos + height;

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
    _computedWidth += e.width;
    if (e is! Separator) {
      _computedWidthNoSeparators += e.width;
    } else {
      _separatorCount++;
    }
  }

  void calculateSeparatorWidth() {
    PageSize size = GetIt.instance.get<PageSize>();
    if (alignment == LineAlignment.justify) {
      double spaceWidth = (size.canvasWidth - rightIndent - (leftIndent + textIndent + dropCapsIndent + _computedWidthNoSeparators)) / _separatorCount;

      for (LineElement e in elements) {
        if (e is Separator) {
          e.width = spaceWidth;
        }
      }
    } else if (alignment == LineAlignment.centre) {
      // Adjust left margin now we know the width of the words in the line.
      double margin = (size.canvasWidth - _computedWidth) / 2;
      leftIndent = margin;
      rightIndent = size.canvasWidth - margin;
    } else {
      if (alignment == LineAlignment.right) {
        leftIndent = rightIndent - _computedWidth;
        textIndent = 0;
      }
    }
  }

  void completeLine() {
    if (elements.isNotEmpty) {
      while (elements.last is SpaceSeparator) {
        elements.removeLast();
        _separatorCount--;
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
    return (_computedWidth + e.width) <= size.canvasWidth;
  }
}