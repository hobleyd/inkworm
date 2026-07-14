import 'dart:math';

import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../styles/block_style.dart';
import '../elements/separators/non_breaking_space_separator.dart';
import '../elements/separators/separator.dart';
import '../elements/separators/space_separator.dart';
import '../elements/line_element.dart';

class Line {
  LineAlignment alignment = LineAlignment.justify;
  double availableWidth = 0;
  double baselineAdjust = 0;
  double dropCapsIndent = 0;
  double lineHeight     = 0;
  double maxAscent      = 0;
  double maxLineHeight  = 0;
  double leftIndent     = 0;
  double rightIndent    = 0;
  double textIndent     = 0;
  double yPosOnPage     = 0; // Should only be used when rendering the line. Otherwise, the calculations should be off the Page.

  List<LineElement> elements = [];
  bool _alignmentCalculated = false;

  bool   get isEmpty            => elements.isEmpty;
  bool   get lastElementIsSpace => elements.isNotEmpty && (elements.last is SpaceSeparator || elements.last is NonBreakingSpaceSeparator);
  int    get separators         => elements.whereType<Separator>().length;
  double get elementsWidth      => elements.fold(0, (sum, item) => sum + item.width);
  double get leftIndents        => leftIndent + textIndent + dropCapsIndent;
  double get width              => leftIndents + elementsWidth;

  set height(double height)     => lineHeight = max(height, lineHeight);
  set ascent(double a)          => maxAscent  = max(a, maxAscent);
  set maxHeight(double height)  => maxLineHeight = max(height, maxLineHeight);
  set yPos(double pos)          => yPosOnPage = pos;

  Line({double? availableWidth, double? leftIndent, double? rightIndent}) {
    PageSize size = GetIt.instance.get<PageSize>();

    this.availableWidth = availableWidth ?? size.canvasWidth;
    this.leftIndent = leftIndent ?? size.leftIndent;
    this.rightIndent = rightIndent ?? size.rightIndent;
  }

  void add(LineElement e) => elements.add(e);

  void calculateSeparatorWidth() {
    if (alignment == LineAlignment.justify) {
      double additionalSpaceWidth = (availableWidth - rightIndent - elements.first.marginRight - width) / separators;

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
      // Adjust left margin now we know the width of the words in the line. leftIndent/rightIndent
      // already hold the page's base insets, and textIndent already holds any CSS margin-left, so
      // both need to be excluded from the box width or they end up applied twice (once here, once
      // again when textIndent is added back on top during painting).
      double margin = (availableWidth - leftIndent - rightIndent - textIndent - elementsWidth - elements.first.marginRight) / 2;
      leftIndent = leftIndent + margin;
      rightIndent = rightIndent + elements.first.marginRight + margin;
    } else {
      if (alignment == LineAlignment.right) {
        leftIndent = availableWidth - width;
        textIndent = 0;
      }
    }
  }

  void completeLine() {
    if (elements.isNotEmpty && !_alignmentCalculated) {
      while (elements.last is SpaceSeparator) {
        elements.removeLast();
      }

      calculateSeparatorWidth();
      _alignmentCalculated = true;
    }
  }

  void completeParagraph() {
    // Don't justify the last line in a paragraph.
    if (alignment == LineAlignment.justify) {
      alignment = LineAlignment.left;
    }
  }

  void setTextIndent(double? indent) {
    PageSize size = GetIt.instance.get<PageSize>();
    textIndent = indent ?? size.leftIndent * 3;
  }

  @override
  String toString() {
    String result = "YP: $yPosOnPage: YP+H: ${yPosOnPage + lineHeight}: WI: $width: ${alignment.name}: LI: $leftIndent: RI: $rightIndent: TI: $textIndent: DCI: $dropCapsIndent: ";
    for (var el in elements) {
      result += '$el';
    }

    return result;
  }

  bool willFitWidth(LineElement e) {
    return (width + e.width) <= (availableWidth - rightIndent - e.marginRight);
  }
}

extension LineListMetrics on List<Line> {
  double get totalHeight => fold(0.0, (sum, line) => sum + line.lineHeight);
}
