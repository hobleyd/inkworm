import 'package:xml/xml.dart';

import '../parser/css_parser.dart';
import '../parser/extensions.dart';

/*
 * This is the abstract base class for the styles; I split CSS styles up into two - BlockStyle for those declarations related to blocks
 * and ElementStyle which relates entirely to text rendering.
 */
abstract class Style {
  Set<String> selectors = {};
  CssDeclarations declarations = {};

  Style parseElement({required XmlNode element, Style? parentStyle});

  void addDeclarations(CssParser parser, XmlNode node) {
    if (node is XmlElement) {
      CssDeclarations matched = parser.matchClassSelectors(node, selectors);
      declarations = declarations.combine(matched);
    }
  }

  void addSelectors(XmlNode node) {
    if (node is XmlElement) {
      selectors = node.selectorSet;
    }
  }
}