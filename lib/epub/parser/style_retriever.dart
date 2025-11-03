import 'package:xml/xml.dart';
import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';

class StyleRetriever {
  final StyleSheet styleSheet;

  StyleRetriever({required this.styleSheet});

  /// Retrieves styles for an XmlElement from the CSS stylesheet
  Map<String, String> getStylesForElement(XmlElement element) {
    final styles = <String, String>{};

    // Get inline styles first (highest priority)
    final inlineStyle = element.getAttribute('style');
    if (inlineStyle != null) {
      styles.addAll(_parseInlineStyle(inlineStyle));
    }

    // Iterate through all top-level rules in the stylesheet
    for (final topLevel in styleSheet.topLevels) {
      _extractStylesFromTopLevel(topLevel, element, styles);
    }

    return styles;
  }

  /// Extracts styles from any top-level construct (rules or directives)
  void _extractStylesFromTopLevel(TreeNode topLevel, XmlElement element, Map<String, String> styles) {
    if (topLevel is RuleSet) {
      if (_selectorMatches(topLevel.selectorGroup, element)) {
        for (final decl in topLevel.declarationGroup.declarations) {
          if (decl is Declaration) {
            final value = _expressionToString(decl.expression);
            styles[decl.property] = value;
          }
        }
      }
    } else if (topLevel is MediaDirective) {
      // Recursively process rules inside media directives
      for (final rule in topLevel.rules) {
        _extractStylesFromTopLevel(rule, element, styles);
      }
    } else if (topLevel is SupportsDirective) {
      // Handle @supports directives
      for (final rule in topLevel.groupRuleBody) {
        _extractStylesFromTopLevel(rule, element, styles);
      }
    }
  }
  String? getStyleProperty(XmlElement element, String property) {
    return getStylesForElement(element)[property];
  }

  /// Checks if a selector group matches an element
  bool _selectorMatches(SelectorGroup? selectorGroup, XmlElement element) {
    if (selectorGroup == null) return false;

    for (final selector in selectorGroup.selectors) {
      if (_singleSelectorMatches(selector, element)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a single selector matches an element
  bool _singleSelectorMatches(Selector selector, XmlElement element) {
    // Get all simple selector sequences in this selector
    if (selector.simpleSelectorSequences.isEmpty) {
      return false;
    }

    // For now, just check the first simple selector
    final firstSequence = selector.simpleSelectorSequences.first;
    return _simpleSelectorSequenceMatches(firstSequence, element);
  }

  /// Checks if a simple selector sequence matches an element
  bool _simpleSelectorSequenceMatches(
      SimpleSelectorSequence sequence, XmlElement element) {
    final simpleSelector = sequence.simpleSelector;

    if (simpleSelector is ElementSelector) {
      final elementName = element.name.toString();
      if (simpleSelector.name != elementName &&
          simpleSelector.name != '*') {
        return false;
      }
    } else if (simpleSelector is IdSelector) {
      if (element.getAttribute('id') != simpleSelector.name) {
        return false;
      }
    } else if (simpleSelector is ClassSelector) {
      final classes = element.getAttribute('class')?.split(' ') ?? [];
      if (!classes.contains(simpleSelector.name)) {
        return false;
      }
    } else {
      // Unknown selector type, skip
      return false;
    }
    return true;
  }

  /// Converts an Expression object to a string value
  String _expressionToString(Expression? expr) {
    if (expr == null) return '';

    if (expr is Expressions) {
      final buffer = StringBuffer();
      for (int i = 0; i < expr.expressions.length; i++) {
        final term = expr.expressions[i];
        buffer.write(_termToString(term));
        if (i < expr.expressions.length - 1) {
          buffer.write(' ');
        }
      }
      return buffer.toString().trim();
    }

    return _termToString(expr);
  }

  /// Converts a Term object to a string value
  String _termToString(dynamic term) {
    if (term is LiteralTerm) {
      return term.value.toString() ?? '';
    } else if (term is NumberTerm) {
      return '${term.value}';
    } else if (term is EmTerm) {
      return '${term.value}em';
    } else if (term is HexColorTerm) {
      return '#${term.value}';
    }
    return term.toString().trim();
  }

  /// Parses inline style attribute into a map
  Map<String, String> _parseInlineStyle(String styleString) {
    final styles = <String, String>{};
    final declarations = styleString.split(';');

    for (final declaration in declarations) {
      if (declaration.trim().isEmpty) continue;
      final parts = declaration.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim().toLowerCase();
        final value = parts[1].trim();
        styles[key] = value;
      }
    }

    return styles;
  }
}
