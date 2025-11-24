import '../elements/line_element.dart';
import 'html_content.dart';

class MarginContent extends HtmlContent {
  @override
  Iterable<LineElement> get elements => [];

  double get margin => blockStyle.marginTop > 0 ? blockStyle.marginTop: blockStyle.marginBottom;

  const MarginContent({required super.blockStyle, required super.elementStyle,});

  @override
  String toString() {
    return blockStyle.toString();
  }
}
