import '../../content/text_content.dart';
import '../../styles/block_style.dart';
import '../../styles/element_style.dart';
import '../line_element.dart';

abstract class Separator extends LineElement {
  final String separator;
  final BlockStyle blockStyle;
  final ElementStyle elementStyle;
  final double separatorAscent;

  @override
  get element => TextContent(text: separator, blockStyle: blockStyle, elementStyle: elementStyle, ascent: 0, descent: 0, width: 0, height: 0);

  @override
  double get ascent => separatorAscent;

  Separator({required this.separator, required this.blockStyle, required this.elementStyle, super.width = 0, super.height = 0, this.separatorAscent = 0});
}