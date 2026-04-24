import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:ordered_set/ordered_set.dart';
import 'package:xml/xml.dart';

import '../../models/element_size.dart';
import '../../models/page_size.dart';
import '../styles/element_style.dart';
import '../styles/style.dart';
import 'epub_parser.dart';
import 'extensions.dart';
import 'isolates/worker_slot.dart';

@Singleton()
class CssParser {
  final Map<String, CssDeclarations> css = {};
  final Set<String> nonInheritableProperties = {};
  final Set<String> _enabledMediaTypes = {};        // ← new

  CssDeclarations? operator [](String key) => css[key];

  CssParser() {
    nonInheritableProperties.add("margin");
    nonInheritableProperties.add("margin-left");
    nonInheritableProperties.add("margin-right");
    nonInheritableProperties.add("margin-top");
    nonInheritableProperties.add("margin-bottom");
  }

  // TODO: test out support for @media elements if ever required.
  void enableMedia(String mediaType) {
    _enabledMediaTypes.add(mediaType);
  }

  Future <double?> getFloatAttribute(XmlNode element, String attribute, Style style, bool isHorizontal) async {
    String? textIndent = getStringAttribute(element, style, "text-indent");

    if (textIndent != null) {
      if (textIndent.endsWith(' !important')) {
        textIndent = textIndent.replaceAll(' !important', '');
      }

      return getFloatFromString((style as ElementStyle).textStyle, textIndent, true);
    }

    return null;
  }

  String? getFontAttribute(XmlNode element, Style style, String attribute) {
    String? value = getCSSAttributeValue(element, style, attribute);

    if (value != null) {
      if (value.contains(',')) {
        // Flutter doesn't provide an API to tell whether a font exists, or not, sigh, so just return the first one.
        return value.split(',').first;
      }
      return value;
    }

    return null;
  }

  double? getPercentAttribute(XmlNode element, Style style, String attribute) {
    String? result = getStringAttribute(element, style, attribute);
    if (result != null) {
      if (result.endsWith('%')) {
        return parseFloatCssValue(result, 1);
      }
    }

    return null;
  }

  String? getStringAttribute(XmlNode element, Style style, String attribute) {
    String? result = element.getAttribute(attribute);
    if (result != null) return result;

    return getCSSAttributeValue(element, style, attribute);
  }

  String? getCSSAttributeValue(XmlNode node, Style style, String attribute) {
    if (node is XmlElement) {
      // First preference inline styles
      CssDeclarations? local = getInlineStyle(node);
      if (local != null && local.containsKey(attribute)) {
        if (local[attribute] != 'inherit') {
          return local[attribute];
        }
      }

      // Then preference direct styles if, we haven't specified inherit in the inline style
      if (local == null || local[attribute] != 'inherit') {
        if (style.declarations.containsKey(attribute)) {
          if (style.declarations[attribute] != 'inherit') {
            return style.declarations[attribute];
          }
        }
      }
    }

    // Now look for style inheritance
    if (!nonInheritableProperties.contains(attribute)) {
      if ((!style.declarations.containsKey(attribute) || style.declarations[attribute] == 'inherit') && node.parentElement != null) {
        Style parentStyle = style;
        if (style is ElementStyle && style.parentStyle != null) {
          parentStyle = style.parentStyle!;
        }
        return getCSSAttributeValue(node.parentElement!, parentStyle, attribute);
      }
    }

    return null;
  }

  Future<double?> getFloatFromString(TextStyle s, String value, bool isHorizontal) async {
    if (value == "0") {
      return 0;
    }
    ElementSize result = await WorkerSlot.measureTextInMainThread("s", s);
    double preferredSize = isHorizontal ? result.width : result.height;

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

  double? getFontSize(XmlNode element, Style style, String attribute, double preferredSize) {
    String? fontSizeString = getStringAttribute(element, style, attribute);
    if (fontSizeString != null) {
      final fontSize = parseFloatCssValue(fontSizeString, preferredSize);
      return fontSize;
    }

    return preferredSize;
  }

  FontWeight getFontWeight(String fontWeight) {
    return switch(fontWeight) {
      "normal"  || "400"  => FontWeight.w400,
      "bold"    || "700"  => FontWeight.w700,
      "bolder"  || "900"  => FontWeight.w900,
      "lighter" || "300"  => FontWeight.w300,
      "100"               => FontWeight.w100,
      "200"               => FontWeight.w200,
      "500"               => FontWeight.w500,
      "600"               => FontWeight.w600,
      "800"               => FontWeight.w800,
      _                   => FontWeight.w400,
    };
  }

  CssDeclarations? getInlineStyle(XmlElement element) {
    String? styles = element.getAttribute("style");

    if (styles != null) {
      return parseDeclarations(styles);
    }

    return null;
  }


  /*
   * CSS hierarchy:
   *   h2.class
   *   .class
   *   class
   *   h2
   */
  CssDeclarations matchClassSelectors(XmlElement element, OrderedSet<String> selectors) {
    CssDeclarations declarations = {};

    // CSS styles are additive, so we need to check everything. But the hierarchy is important in the case we have
    // over-riding values. CSS is clearly defined by committee. Sigh.
    declarations = declarations.combine(css[element.localName]);

    // Check the basic CSS hierarchy
    for (String selector in selectors.reversed()) {
      declarations = declarations.combine(css[selector]);
      declarations = declarations.combine(css['.$selector']);
      declarations = declarations.combine(css['${element.localName}.$selector']);
    }

    // Apparently you can specify multiple subsets of the class elements and expect this to match
    // <p class="a,b,c,d,e"> can match css selections ".a.b.e", ".a.c.d", ".a.e.b.d" etc. Go figure.
    OrderedSet<String> complexSelectors = stripSimpleSelectors(selectors);
    for (String cssKey in css.keys) {
      if (isMatchedSingleLevelSelectors(cssKey, complexSelectors.toSet())) {
          declarations = declarations.combine(css[cssKey]);
      }
    }

    for (String cssKey in css.keys) {
      if (cssKey.contains(' ')) {
        if (isMatchedMultiLevelSelectors(element, cssKey.split(' ').toSet())) {
          declarations = declarations.combine(css[cssKey]);
        }
      }
    }

    return declarations;
  }

  bool isMatchedSingleLevelSelectors(String selector, Set<String> selectors) {
    if (selector.contains('.')) {
      Set<String> selectorParts = selector.split('.').where((sel) => sel.isNotEmpty).toSet();
      return selectorParts.difference(selectors).isEmpty;
    }

    return false;
  }

  /*  You also need to check (non contiguous) parent class entries in order:
   * <div id="unnumbered-1" class="element element-bodymatter element-container-single element-type-chapter element-without-heading">
   *     <div class="text" id="unnumbered-1-text">
   *       <div class="inline-image inline-image-kind-photograph inline-image-size-medium inline-image-flow-center inline-image-flow-within-text inline-image-aspect-wide block-height-not-mult-of-line-height inline-image-without-caption inline-image-begins-section inline-image-before-element-end">
   *         <div class="inline-image-container">
   *           <img src="images/chapno-1.jpg" alt="" />
   *         </div>
   *       </div>
   *       <p class="implicit-break"></p>
   *       <p class="first first-in-chapter first-full-width first-with-first-letter-a"><b><i><span class="first-letter first-letter-a first-letter-without-punctuation">A</span>s</i></b> I have often opined, what good does it do a fellow to be a master of the mystic arts if he’s not allowed to do a bally thing with said mastery? And while I’ll admit that knocking the toppers off one’s fellow practitioners at Goodwood might have been a tad childish, it hardly, to my mind, constituted a hanging offence. Alas, the old sticks at the Folly didn’t see eye to eye with me on this, so I decided that perhaps it would be wise to remove myself somewhere out of their censorious gaze until the blissful waters of Lethe bathed their cares away. Or something.</p>
   * Needs to match the selector:
   * .element-container-single.element-bodymatter p.first-in-chapter.first-full-width span.first-letter
   */
  bool isMatchedMultiLevelSelectors(XmlElement element, Set<String> selectors) {
    if (element.getAttribute("class") != null) {
      Set<String> matchedSelectors = element.getAttribute("class")!.split(" ").toSet();
      for (String matchedSelector in matchedSelectors) {
        selectors.remove(matchedSelector);
        selectors.remove('.$matchedSelector');
        selectors.remove('${element.localName}.$matchedSelector');
      }

      if (selectors.isNotEmpty) {
        String lastSelector = selectors.last;
        if (lastSelector.startsWith(element.localName)) {
          lastSelector = lastSelector.replaceFirst('${element.localName}.', '');
        }
        if (isMatchedSingleLevelSelectors(lastSelector, matchedSelectors)) {
          selectors.remove(selectors.last);
        }
      }
    }

    if (selectors.isEmpty) {
      return true;
    } else {
      if (element.parentElement != null) {
        return isMatchedMultiLevelSelectors(element.parentElement!, selectors);
      } else {
        return false;
      }
    }
  }

  void parseCss(String cssContent) {
    Map<String, CssDeclarations> result = {};

    // Remove comments
    var cleaned = cssContent.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    cleaned = cleaned.replaceAll(RegExp(r'@namespace url\(.*\);'), '');

    // strip out @media blocks, inlining rules only for enabled types
    cleaned = _resolveMediaBlocks(cleaned);

    // Regular expression to match selector { properties }
    final regExp = RegExp(r'([^{]+)\{\s*([^}]*)\s*\}');

    final matches = regExp.allMatches(cleaned);
    for (final match in matches) {
      String selector = match.group(1)?.trim() ?? '';
      final String properties = match.group(2)?.trim() ?? '';

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

              if (declarations['src'] != null) {
                WorkerSlot.loadFont(individual, declarations['src']!);
              }
            }

            result.combine(individual, declarations);
          }
        }
      }
    }

    for (String selector in result.keys) {
      css.combine(selector, result[selector]!);
    }
  }

  CssDeclarations parseDeclarations(String properties) {
    // TODO: Do I really need to support css3?
    if (properties.startsWith('@supports')) {
      return {};
    }

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
          throw FormatException("CSS declarations not splitting into 2!\n$properties");
        }
      }
    }

    return declarations;
  }

  void parseFile(String href) {
    if (!css.containsKey(href)) {
      parseCss(GetIt.instance.get<EpubParser>().bookArchive!.getContentAsString(href));
    }
  }

  double parseFloatCssValue(String value, double preferredSize) {
    if (value.isNotEmpty) {
      final cssFloatRegex = RegExp(r'^(-?\d+\.?\d*)([a-z%]+)$', caseSensitive: false);
      final match = cssFloatRegex.firstMatch(value.trim());

      PageSize size = GetIt.instance.get<PageSize>();
      if (match != null) {
        return switch (match.group(2)){
          "px" || "pt" => size.pixelDensity * double.parse(match.group(1)!),
          "em"         => preferredSize * double.parse(match.group(1)!),
          "%"          => preferredSize * (double.parse(match.group(1)!) / 100),
          _ => double.parse(match.group(1)!),
        };
      }

      // If we get here, we have textual representation of sizes "small", "large" etc.
      return preferredSize * getFontMultiplier(value);
    }

    // Give up and return the default.
    return preferredSize;
  }

  OrderedSet<String> stripSimpleSelectors(OrderedSet<String> selectors) {
    OrderedSet<String> complexSelectors = OrderedSet.simple<String>();
    complexSelectors.addAll(selectors);

    complexSelectors.removeWhere((selector) => '.'.allMatches(selector).length <= 1);
    return complexSelectors;
  }

  /// Finds all @media blocks in [css]. If the media type is in [_enabledMediaTypes],
  /// the inner rules are inlined into the returned string. Otherwise the block is dropped.
  String _resolveMediaBlocks(String css) {
    final buffer = StringBuffer();
    int i = 0;

    while (i < css.length) {
      final mediaStart = css.indexOf('@media', i);
      if (mediaStart == -1) {
        // No more @media blocks — append remainder and stop
        buffer.write(css.substring(i));
        break;
      }

      // Append everything before this @media block
      buffer.write(css.substring(i, mediaStart));

      // Find the opening brace
      final braceOpen = css.indexOf('{', mediaStart);
      if (braceOpen == -1) break; // malformed, give up

      // Extract the media query string, e.g. "amzn-mobi" or "screen and (max-width: 600px)"
      final mediaQuery = css.substring(mediaStart + '@media'.length, braceOpen).trim();

      // Find the matching closing brace (accounting for nesting)
      final braceClose = _findMatchingBrace(css, braceOpen);
      if (braceClose == -1) break; // malformed, give up

      // The inner content (the rules inside the @media block)
      final innerContent = css.substring(braceOpen + 1, braceClose);

      if (_isMediaEnabled(mediaQuery)) {
        buffer.write(innerContent);
      }
      // else: drop the block entirely

      i = braceClose + 1;
    }

    return buffer.toString();
  }

  /// Returns true if [mediaQuery] matches any of the enabled media types.
  /// Handles bare names ("amzn-mobi") and "only screen"-style prefixes.
  bool _isMediaEnabled(String mediaQuery) {
    final query = mediaQuery.toLowerCase().trim();
    return _enabledMediaTypes.any((type) => query == type.toLowerCase() ||
        query.startsWith('${type.toLowerCase()} '));
  }

  /// Finds the index of the closing brace that matches the opening brace at [openIndex].
  int _findMatchingBrace(String s, int openIndex) {
    int depth = 0;
    for (int i = openIndex; i < s.length; i++) {
      if (s[i] == '{') depth++;
      else if (s[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1; // unmatched
  }
}