import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

abstract class HtmlHandler {
  static final HashMap<String, HtmlHandler> _htmlHandlers = HashMap<String, HtmlHandler>();

  static HtmlHandler? getHandler(String key) => _htmlHandlers[key];

  InlineSpan processElement(XmlElement element);

  static void registerHandler(String key, HtmlHandler handler) {
    _htmlHandlers[key] = handler;
  }
}
