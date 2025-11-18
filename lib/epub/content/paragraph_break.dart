import 'package:inkworm/epub/styles/block_style.dart';

import '../elements/line_element.dart';
import 'html_content.dart';

class ParagraphBreak extends HtmlContent {
  @override
  Iterable<LineElement> get elements => [];

  const ParagraphBreak({required super.blockStyle, required super.elementStyle,});
}
