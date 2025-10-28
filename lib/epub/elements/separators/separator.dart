import '../../content/text_content.dart';
import '../../styles/block_style.dart';
import '../line_element.dart';

abstract class Separator extends LineElement {
  final TextContent separator;
  final BlockStyle style;

  @override
  get element => separator;

  Separator({required this.separator, required this.style});
}