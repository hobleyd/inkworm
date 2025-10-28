import 'dart:collection';

import 'package:xml/xml.dart';

import '../content/html_content.dart';

abstract class HtmlHandler {
  static final HashMap<String, HtmlHandler> _htmlHandlers = HashMap<String, HtmlHandler>();

  static HtmlHandler? getHandler(String key) => _htmlHandlers[key];

  Future<List<HtmlContent>> processElement(XmlElement element);

  static void registerHandler(String key, HtmlHandler handler) {
    _htmlHandlers[key] = handler;
  }
}
