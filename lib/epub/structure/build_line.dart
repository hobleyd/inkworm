import 'package:injectable/injectable.dart';

import '../elements/line_element.dart';
import '../elements/separators/space_separator.dart';
import '../elements/word_element.dart';
import '../interfaces/line_listener.dart';
import '../styles/block_style.dart';
import 'line.dart';

@LazySingleton()
class BuildLine {
  LineListener? _lineListener;
  Line currentLine = Line();

  bool alignmentToBaselineRequired = false;

  bool   get isEmpty    =>  currentLine.isEmpty;
  bool   get isNotEmpty => !currentLine.isEmpty;
  double get maxHeight  =>  currentLine.lineHeight;

  set dropCapsIndent(double indent)        => currentLine.dropCapsIndent = indent;
  set lineListener(LineListener? listener) => _lineListener = listener;
  set textIndent(double indent)            => currentLine.setTextIndent(indent);

  void addElement(LineElement e) {
    // We don't add multiple spaces together unless they are non-breaking.
    if (e is SpaceSeparator) {
      if (currentLine.lastElementIsSpace) {
        return;
      }

      if (currentLine.isEmpty) {
        return;
      }
    }

    // The first time through, we hit the else clause as we don't know yet, what we need.
    // But if we do need an adjustment, then we calculate it the second time through when
    // we know the actual height.
    if (alignmentToBaselineRequired) {
      currentLine.baselineAdjust = currentLine.lineHeight - e.height;
      alignmentToBaselineRequired = false;
    } else if (e.alignToBaseline) {
      // We need to adjust the yPos of both the element and the line if we are aligning to the baseline.
      alignmentToBaselineRequired = true;
    }

    currentLine.maxHeight = e.height;
    if (!e.isDropCaps) {
      // Only adjust the line height if this is not a dropcaps element. For obvious reasons. Given the use of dropcaps I can't
      // imagine it will be possible that this is the only thing on the line. On the other hand. HTML. Sigh.
      currentLine.height = e.height;

      if (!currentLine.isEmpty && currentLine.elements.first is WordElement) {
        final WordElement first = currentLine.elements.first as WordElement;
        if (first.isDropCaps) {
          (currentLine.elements.first as WordElement).dropCapsAdjust = currentLine.lineHeight - first.word.descent + 2;
        }
      }
    }

    if (!currentLine.willFitWidth(e) && e is! SpaceSeparator) {
      completeLine();

      currentLine.leftIndent += e.element.blockStyle.marginLeft;

      // If we create a new line, this will not have the height from the previous assignment (obviously). Also,
      // it can't be a dropcaps as that would fit on the line given they are always at the start of a sentence.
      currentLine.height = e.height;
    }

    currentLine.add(e);
  }

  void addLine() {
    currentLine = Line();
  }

  void completeLine() {
    currentLine.completeLine();
    notifyListeners();
  }

  void completeParagraph() {
    // Don't justify the last line in a paragraph.
    if (currentLine.alignment == LineAlignment.justify) {
      currentLine.alignment = LineAlignment.left;
    }
    completeLine();
  }

  void notifyListeners() {
    _lineListener?.addLine(currentLine, this);
  }

  void setAlignment(LineAlignment? alignment) {
    if (currentLine.isEmpty) {
      currentLine.alignment = alignment ?? LineAlignment.justify;
    }
  }
}