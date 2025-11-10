import '../../content/text_content.dart';
import '../../styles/block_style.dart';
import '../../styles/element_style.dart';
import '../line_element.dart';

abstract class Separator extends LineElement {
  final String separator;
  final BlockStyle blockStyle;
  final ElementStyle elementStyle;

  @override
  get element => TextContent(text: separator, blockStyle: blockStyle, elementStyle: elementStyle);

  Separator({required this.separator, required this.blockStyle, required this.elementStyle});
}