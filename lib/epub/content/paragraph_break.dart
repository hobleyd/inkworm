import '../elements/line_element.dart';
import 'html_content.dart';

class ParagraphBreak extends HtmlContent {
  @override
  Iterable<LineElement> get elements => [];

  double get margin => blockStyle.marginTop > 0 ? blockStyle.marginTop: blockStyle.marginBottom;

  const ParagraphBreak({required super.blockStyle, required super.elementStyle,});

  @override
  bool operator ==(Object other) {
    if (other is ParagraphBreak) {
      return blockStyle.bottomMargin == other.blockStyle.bottomMargin &&
          blockStyle.topMargin == other.blockStyle.topMargin &&
          blockStyle.leftMargin == other.blockStyle.leftMargin &&
          blockStyle.rightMargin == other.blockStyle.rightMargin;
    }
    return false;
  }

  @override
  String toString() {
    return blockStyle.toString();
  }

  @override
  int get hashCode => Object.hash(blockStyle.leftMargin, blockStyle.rightMargin, blockStyle.topMargin, blockStyle.bottomMargin,);
}
