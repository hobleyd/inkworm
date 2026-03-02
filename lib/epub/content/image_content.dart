import '../elements/image_element.dart';
import '../elements/line_element.dart';
import 'html_content.dart';

class ImageContent extends HtmlContent {
  String image;

  double height;
  double width;

  @override
  Iterable<LineElement> get elements => [ImageElement(image: this)];

  ImageContent({
    required super.blockStyle,
    required super.elementStyle,
    required this.image,
    required this.width,
    required this.height,
  });

  @override
  String toString() {
    return 'IMG: orig: $width/$height: resized: ${elements.first.width}/${elements.first.height}';
  }
}
