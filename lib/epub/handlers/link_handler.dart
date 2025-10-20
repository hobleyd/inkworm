import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:xml/xml.dart';

import '../parser/epub_parser.dart';
import 'html_handler.dart';

@Named("LinkHandler")
@Singleton(as: HtmlHandler)
class LinkHandler extends HtmlHandler {
  LinkHandler() {
    HtmlHandler.registerHandler('link', this);
  }

  @override
  InlineSpan processElement(XmlElement element) {
    debugPrint('LINK_HANDLER: ${element.name}: ${element.attributes}');
    if ('${element.getAttribute("rel")}' == "stylesheet") {
      GetIt.instance.get<CssParser>().parseFile(element.getAttribute("href")!);

    }
    return TextSpan(text: element.innerText);
  }
}