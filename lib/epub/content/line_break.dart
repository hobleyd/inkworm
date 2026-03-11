import '../elements/line_element.dart';
import 'html_content.dart';

class LineBreak extends HtmlContent {
  @override
  Iterable<LineElement> get elements => [];

  double get margin => blockStyle.marginTop > 0 ? blockStyle.marginTop: blockStyle.marginBottom;

  const LineBreak({required super.blockStyle, required super.elementStyle, required super.height, required super.width});

  @override
  String toString() {
    return 'LB: $blockStyle';
  }
}
