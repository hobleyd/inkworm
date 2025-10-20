import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'epub_parser.dart';
import 'extensions.dart';

typedef CssDeclarations = Map<String, String>;

@Singleton()
class CssParser {
  final Map<String, CssDeclarations> css = {};

  CssParser();

  CssDeclarations? operator [](String selector) => css[selector];

  void parseCss(String cssContent) {
    var cleaned = cssContent.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

    // Regular expression to match selector { properties }
    final regExp = RegExp(r'([^{]+)\{\s*([^}]*)\s*\}');

    final matches = regExp.allMatches(cleaned);
    for (final match in matches) {
      String selector = match.group(1)?.trim() ?? '';
      final String properties = match.group(2) ?? '';

      if (selector.isNotEmpty) {
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

        // Split comma-separated selectors and add each individual with the same properties
        final selectors = selector.split(',');
        for (final sel in selectors) {
          final individual = sel.trim();
          if (individual.isNotEmpty) {
            css[individual] = declarations;
          }
        }

        // We can't use a Map for @font-face as they keys appear to be identical, so reference by font-family instead.
        // We'll need to deal with this in Element parsing, obviously.
        if (selector == "@font-face") {
          selector = declarations["font-family"]!.replaceAll('"', '');
          declarations.remove("font-family");
        }
      }
    }
  }

  void parseFile(String href) {
    if (!css.containsKey(href)) {
      parseCss(GetIt.instance.get<EpubParser>().bookArchive.getContentAsString(href));
    }
  }
}