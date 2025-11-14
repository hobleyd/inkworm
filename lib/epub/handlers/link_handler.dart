import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import '../parser/css_parser.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

@Named("LinkHandler")
@Singleton(as: HtmlHandler)
class LinkHandler extends HtmlHandler {
  LinkHandler() {
    HtmlHandler.registerHandler('link', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;
    if ('${element.getAttribute("rel")}' == "stylesheet") {
      GetIt.instance.get<CssParser>().parseFile(element.getAttribute("href")!);

    }
    return [];
  }
}