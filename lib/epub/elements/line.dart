
import 'dart:math';

import '../constants.dart';
import 'separators/separator.dart';
import 'line_element.dart';

enum LineAlignment { left, right, centre, justify }

class Line {
  LineAlignment alignment = LineAlignment.justify;
  double yPos = 0;
  double height = 0;
  double _computedWidth = 0;
  double _computedWidthNoSeparators = 0;
  double _leftIndent = PageConstants.leftIndent;
  double _rightIndent = PageConstants.rightIndent;
  double _spaceWidth = 0;
  double textIndent = 0;
  int _separatorCount = 0;

  List<LineElement> elements = [];

  get canvasWidth => PageConstants.canvasWidth - PageConstants.leftIndent - PageConstants.rightIndent;

  Line({required this.yPos,});

  void addElement(LineElement e) {
    assert(willFit(e));

    if (!e.isDropCaps) {
      // Only adjust the line height if this is not a dropcaps element. For obvious reasons.
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
    if (alignment == LineAlignment.justify) {
      _spaceWidth = (PageConstants.canvasWidth - _rightIndent - (_leftIndent + textIndent + _computedWidthNoSeparators)) / _separatorCount;

      for (LineElement e in elements) {
        if (e is Separator) {
          e.width = _spaceWidth;
        }
      }
    } else if (alignment == LineAlignment.centre) {
      // Adjust left margin now we know the width of the words in the line.
      double margin = (canvasWidth - _computedWidth) / 2;
      _leftIndent = margin;
      _rightIndent = canvasWidth - margin;
    } else {
      if (alignment == LineAlignment.right) {
        _leftIndent = _rightIndent - _computedWidth;
        textIndent = 0;
      }
    }
  }

  void finish() {
    while (elements.last is Separator) {
      elements.removeLast();
      _separatorCount--;
    }

    calculateSeparatorWidth();
  }

  @override
  String toString() {
    String result = "$textIndent: ";
    for (var el in elements) {
      result += '$el';
    }

    return result;
  }

  bool willFit(LineElement e) {
    return (_computedWidth + e.width) < canvasWidth;
  }
}