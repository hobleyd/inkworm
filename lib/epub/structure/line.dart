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

  double dropCapsIndent = 0;
  double maxHeight = 0;
  double leftIndent = 0;
  double rightIndent = 0;
  double textIndent = 0;
  double yPosOnPage = 0; // Should only be used when rendering the line. Otherwise, the calculations should be off the Page.

  List<LineElement> elements = [];

  bool   get isEmpty            => elements.isEmpty;
  bool   get lastElementIsSpace => elements.isNotEmpty && (elements.last is SpaceSeparator || elements.last is NonBreakingSpaceSeparator);
  int    get separators         => elements.whereType<Separator>().length;
  double get leftIndents        => leftIndent + textIndent + dropCapsIndent;
  double get width              => leftIndents + elements.fold(0, (sum, item) => sum + item.width);

  set height(double height)     => maxHeight = max(height, maxHeight);
  set yPos(double pos)          => yPosOnPage = pos;

  Line() {
    PageSize size = GetIt.instance.get<PageSize>();

    leftIndent = size.leftIndent;
    rightIndent = size.rightIndent;
  }

  void add(LineElement e) => elements.add(e);

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
        leftIndent = size.canvasWidth - width;
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

  void setTextIndent(double? indent) {
    PageSize size = GetIt.instance.get<PageSize>();
    textIndent = indent ?? size.leftIndent * 1.5;
  }

  @override
  String toString() {
    String result = "YP: $yPosOnPage: YP+H: ${yPosOnPage + maxHeight}: WI: $width: ${alignment.name}: LI: $leftIndent: RI: $rightIndent: TI: $textIndent: DCI: $dropCapsIndent: ";
    for (var el in elements) {
      result += '$el';
    }

    return result;
  }

  bool willFitWidth(LineElement e) {
    PageSize size = GetIt.instance.get<PageSize>();
    return (width + e.width) <= (size.canvasWidth - rightIndent);
  }
}