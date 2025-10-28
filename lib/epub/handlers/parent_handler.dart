import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../content/html_content.dart';
import 'html_handler.dart';

@Named("ParentHandler")
@Singleton(as: HtmlHandler)
class ParentHandler extends HtmlHandler {
  ParentHandler() {
    HtmlHandler.registerHandler('html', this);
    HtmlHandler.registerHandler('head', this);
    HtmlHandler.registerHandler('body', this);
  }

  @override
  Future<List<HtmlContent>> processElement(XmlElement element) async {
    List<HtmlContent> elements = [];

    for (var child in element.childElements) {
      List<HtmlContent>? childElements = await HtmlHandler.getHandler(child.name.local)?.processElement(child);

      if (childElements != null && childElements.isNotEmpty) {
        elements.addAll(childElements);
      }
    }

    return elements;
  }
}