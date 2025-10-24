import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../constants.dart';
import 'epub_parser.dart';
import 'extensions.dart';

typedef CssDeclarations = Map<String, String>;

@Singleton()
class CssParser {
  final Map<String, CssDeclarations> css = {};

  final Set<String> nonInheritableProperties = {};

  CssDeclarations? operator [](String key) => css[key];

  CssParser() {
    nonInheritableProperties.add("margin");
    nonInheritableProperties.add("margin-left");
    nonInheritableProperties.add("margin-right");
    nonInheritableProperties.add("margin-top");
    nonInheritableProperties.add("margin-bottom");
  }

  double getFloatAttribute(XmlElement element, String attribute, String defaultValue, TextStyle textStyle, bool isHorizontal) {
    String textIndent = getStringAttribute(element, "text-indent", defaultValue);
    return getFloatFromString(textStyle, textIndent, defaultValue, true);
  }

  double getPercentAttribute(XmlElement element, String attribute, String defaultValue) {
    String result = getStringAttribute(element, attribute, defaultValue);
    return result.endsWith('%') ? parseFloatCssValue(result, 1) : 1;
  }

  String getStringAttribute(XmlElement element, String attribute, String defaultValue) {
    String? value = getCSSValue(element, attribute);

    return value ?? defaultValue;
  }

  /*
   * CSS hierarchy:
   * h2.class
   * .class
   * class
   * h2
   */
  String? getCSSValue(XmlElement element, String attribute) {
    // Local style over-rides the CSS file(s)
    String? result = getInlineStyle(element, attribute);

    // No local styles, check the specified class attributes
    if (result == null) {
      final String? elementClasses = element.getAttribute("class");

      if (elementClasses != null) {
        for (var elementClass in elementClasses.split(" ")) {
          result   = css['${element.localName}.$elementClass']?[attribute];
          result ??= css['.$elementClass']?[attribute];
          result ??= css[elementClass]?[attribute];

          if (result != null) {
            break;
          }
        }
      }
    }

    // Fall back to the element itself, if all else fails.
    result ??= css[element.localName]?[attribute];

    // Now look for style inheritance
    if ((result == null || result == 'inherit') && element.hasParent) {
      result = getCSSValue(element.parentElement!, attribute);
    }

    return result;
  }

  double getFloatFromString(TextStyle s, String value, String defaultValue, bool isHorizontal) {
    TextPainter paint = TextPainter(text: TextSpan(text: "s", style: s));
    paint.layout();

    double preferredSize = isHorizontal ? paint.width : paint.height;
    return value.isEmpty ? parseFloatCssValue(defaultValue, preferredSize) : parseFloatCssValue(value, preferredSize);
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

  String? getInlineStyle(XmlElement element, String attribute) {
    String? styles = element.getAttribute("style");

    if (styles != null) {
      return parseDeclarations(styles)[attribute];
    }

    return null;
  }

  static Future<void> loadFontFromEpub(String fontFamily, String fontPath) async {
    // Knowing how the getBytes function works, strip out the relative paths as they won't be needed. Purists will disagree ;-)
    String cleanedPath = fontPath.replaceAll(RegExp(r'^(\.\.\/)+'), '');

    final bytes = GetIt.instance.get<EpubParser>().getBytes(cleanedPath);

    final fontLoader = FontLoader(fontFamily);
    fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();
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
                loadFontFromEpub(individual, declarations['url']!);
              }
            }

            result[individual] = declarations;
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