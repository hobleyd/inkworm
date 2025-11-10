import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../constants.dart';
import 'epub_parser.dart';
import 'font_management.dart';
import 'extensions.dart';
import 'style_retriever.dart';

@Singleton()
class CssParser {
  final Map<String, CssDeclarations> css = {};
  late StyleRetriever retriever;
  final Set<String> nonInheritableProperties = {};

  CssDeclarations? operator [](String key) => css[key];

  CssParser() {
    nonInheritableProperties.add("margin");
    nonInheritableProperties.add("margin-left");
    nonInheritableProperties.add("margin-right");
    nonInheritableProperties.add("margin-top");
    nonInheritableProperties.add("margin-bottom");

    parseDefaultCss();
  }

  double? getFloatAttribute(XmlNode element, String attribute, TextStyle textStyle, bool isHorizontal) {
    String? textIndent = getStringAttribute(element, "text-indent");
    if (textIndent != null) {
      return getFloatFromString(textStyle, textIndent, true);
    }

    return null;
  }

  String? getFontAttribute(XmlNode element, String attribute) {
    String? value = getCSSAttributeValue(element, attribute);

    if (value != null) {
      if (value.contains(',')) {
        // Flutter doesn't provide an API to tell whether a font exists, or not, sigh, so just return the first one.
        return value.split(',').first;
      }
      return value;
    }

    return null;
  }

  double? getPercentAttribute(XmlNode element, String attribute) {
    String? result = getStringAttribute(element, attribute);
    if (result != null) {
      if (result.endsWith('%')) {
        return parseFloatCssValue(result, 1);
      }
    }

    return null;
  }

  String? getStringAttribute(XmlNode element, String attribute) {
    return getCSSAttributeValue(element, attribute);
  }

  /*
   * CSS hierarchy:
   * h2.class
   * .class
   * class
   * h2
   */
  String? getCSSAttributeValue(XmlNode element, String attribute) {
    CssDeclarations declarations = getCSSDeclarations(element);

    // Now look for style inheritance
    if ((declarations.isEmpty || declarations[attribute] == 'inherit') && element.parentElement != null) {
      return getCSSAttributeValue(element.parentElement!, attribute);
    }

    return declarations[attribute];
  }

  CssDeclarations getCSSDeclarations(XmlNode node) {
    XmlElement element = node as XmlElement;
    CssDeclarations declarations = {};

    // Reverse the order of precedence as the combine function will preference the latest values.
    declarations = declarations.combine(css[element.localName]);
    declarations = declarations.combine(css[element]);

    final String? elementClasses = element.getAttribute("class");
    if (elementClasses != null) {
      for (var elementClass in elementClasses.split(" ")) {
        declarations = declarations.combine(css[elementClass]);
        declarations = declarations.combine(css['.$elementClass']);
        declarations = declarations.combine(css['${element.localName}.$elementClass']);
      }
    }
    declarations = declarations.combine(getInlineStyle(element));

    return declarations;
  }

  double? getFloatFromString(TextStyle s, String value, bool isHorizontal) {
    TextPainter paint = TextPainter(textDirection: TextDirection.ltr, text: TextSpan(text: "s", style: s));
    paint.layout();

    double preferredSize = isHorizontal ? paint.width : paint.height;
    return value.isEmpty ? null : parseFloatCssValue(value, preferredSize);
  }

  double getFontMultiplier(String fontSize) {
    return switch(fontSize) {
      "xx-small" => 0.7,
      "x-small"  => 0.8,
      "small"    => 0.9,
      "smaller"  => 0.9,
      "medium"   => 1,
      "large"    => 1.1,
      "larger"   => 1.1,
      "x-large"  => 1.2,
      "xx-large" => 1.3,
      _          => 1
    };
  }

  CssDeclarations? getInlineStyle(XmlElement element) {
    String? styles = element.getAttribute("style");

    if (styles != null) {
      return parseDeclarations(styles);
    }

    return null;
  }

  Map<String, CssDeclarations> parseCss(String cssContent) {
    Map<String, CssDeclarations> result = {};

    var cleaned = cssContent.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

    // Regular expression to match selector { properties }
    final regExp = RegExp(r'([^{]+)\{\s*([^}]*)\s*\}');

    final matches = regExp.allMatches(cleaned);
    for (final match in matches) {
      String selector = match.group(1)?.trim() ?? '';
      final String properties = match.group(2) ?? '';

      if (selector.isNotEmpty) {
        CssDeclarations declarations = parseDeclarations(properties);

        // Split comma-separated selectors and add each individual with the same properties
        final selectors = selector.split(',');
        for (final sel in selectors) {
          String individual = sel.trim();
          if (individual.isNotEmpty) {
            // We can't use a Map for @font-face as the keys appear to be identical, so reference by font-family instead.
            if (individual == "@font-face") {
              individual = declarations["font-family"]!.replaceAll('"', '');
              declarations.remove("font-family");

              if (declarations['url'] != null) {
                GetIt.instance.get<FontManagement>().loadFontFromEpub(individual, declarations['url']!);
              }
            }

            result = result.combine(individual, declarations);
          }
        }
      }
    }

    return result;
  }

  CssDeclarations parseDeclarations(String properties) {
    final CssDeclarations declarations = {};

    // Split properties by semicolon and parse each one
    final props = properties.split(';');
    for (final prop in props) {
      final trimmed = prop.trim();
      if (trimmed.isNotEmpty) {
        final parts = trimmed.split(':');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim();
          declarations[key] = value;
        }
        else {
          throw FormatException("CSS declarations not splitting into 2!");
        }
      }
    }

    return declarations;
  }

  Future<void> parseDefaultCss() async {
    String defaultCss = await rootBundle.loadString('assets/default.css');
    css.addAll(parseCss(defaultCss));
  }

  void parseFile(String href) {
    if (!css.containsKey(href)) {
      Map<String, CssDeclarations> declarations = parseCss(GetIt.instance.get<EpubParser>().bookArchive.getContentAsString(href));
      css.addAll(declarations);
    }
  }

  double parseFloatCssValue(String value, double preferredSize) {
    if (value.isNotEmpty) {
      final cssFloatRegex = RegExp(r'^(-?\d+\.?\d*)([a-z%]+)$', caseSensitive: false);
      final match = cssFloatRegex.firstMatch(value.trim());

      if (match != null) {
        return switch (match.group(2)){
          "px" || "pt" => PageConstants.pixelDensity * double.parse(match.group(1)!),
          "em" => preferredSize * double.parse(match.group(1)!),
          "%" => preferredSize * (double.parse(match.group(1)!) / 100),
          _ => double.parse(match.group(1)!),
        };
      }

      // If we get here, we have textual representation of sizes "small", "large" etc.
      return preferredSize * getFontMultiplier(value);
    }

    // Give up and return the default.
    return preferredSize;
  }

}