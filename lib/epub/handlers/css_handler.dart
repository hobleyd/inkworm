import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../parser/css_parser.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

class CssHandler extends HtmlHandler {
  CssHandler() {
    HtmlHandler.registerHandler('link', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;
    final String? type = element.getAttribute("type");
    // Some (older) epubs include an Adobe Digital Editions page-template link alongside the real
    // stylesheet: <link rel="stylesheet" type="application/vnd.adobe-page-template+xml" .../>.
    // It isn't CSS and the referenced file isn't in the archive, so only treat rel="stylesheet"
    // as CSS when the type is absent or explicitly text/css.
    if ('${element.getAttribute("rel")}' == "stylesheet" && (type == null || type == "text/css")) {
      GetIt.instance.get<CssParser>().parseFile(element.getAttribute("href")!);
    }

    return [];
  }
}