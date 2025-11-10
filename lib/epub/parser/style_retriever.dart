import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as css;
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

@Singleton()
class StyleRetriever {
  late css.StyleSheet styleSheet;

  void parse(String cssString) {
    styleSheet = css.parse(cssString);
    return;
  }

  /// Get all relevant declarations for a node, respecting CSS specificity
  Map<String, css.Expression> getDeclarationsForNode(XmlElement node) {
    final matches = <_RuleMatch>[];

    // Find all matching rules
    for (var rule in styleSheet.topLevels) {
      if (rule is css.RuleSet) {
        for (var selector in rule.selectorGroup?.selectors ?? []) {
          if (_matchesSelector(node, selector)) {
            final specificity = _calculateSpecificity(selector);
            matches.add(_RuleMatch(rule, specificity));
          }
        }
      }
    }

    // Sort by specificity (higher specificity wins)
    matches.sort((a, b) => a.specificity.compareTo(b.specificity));

    // Build final declaration map (later rules override earlier ones)
    final declarations = <String, css.Expression>{};
    for (var match in matches) {
      for (var decl in match.rule.declarationGroup.declarations) {
        if (decl is css.Declaration) {
          declarations[decl.property] = decl.expression!;
        }
      }
    }

    return declarations;
  }

  /// Check if a node matches a CSS selector
  bool _matchesSelector(XmlElement node, css.Selector selector) {
    final sequences = selector.simpleSelectorSequences;
    if (sequences.isEmpty) return false;

    // Start from the rightmost selector (the one that must match the node)
    return _matchesSequences(node, sequences, sequences.length - 1);
  }

  /// Recursively match selector sequences with combinators
  bool _matchesSequences(
      XmlElement node,
      List<css.SimpleSelectorSequence> sequences,
      int currentIndex,
      ) {
    if (currentIndex < 0) return true;

    final currentSequence = sequences[currentIndex];

    // The current node must match the current sequence
    if (!_matchesSimpleSequence(node, currentSequence)) {
      return false;
    }

    // If this is the first sequence, we're done
    if (currentIndex == 0) return true;

    // Get the combinator before this sequence
    final combinator = currentSequence.combinator;

    if (combinator == css.TokenKind.COMBINATOR_DESCENDANT) {
      // Space combinator: match any ancestor
      return _matchesAnyAncestor(node, sequences, currentIndex - 1);
    } else if (combinator == css.TokenKind.COMBINATOR_GREATER) {
      // > combinator: match immediate parent
      final parent = node.parent;
      if (parent is! XmlElement) return false;
      return _matchesSequences(parent, sequences, currentIndex - 1);
    } else if (combinator == css.TokenKind.COMBINATOR_PLUS) {
      // + combinator: match immediately preceding sibling
      final prevSibling = _getPreviousSiblingElement(node);
      if (prevSibling == null) return false;
      return _matchesSequences(prevSibling, sequences, currentIndex - 1);
    } else if (combinator == css.TokenKind.COMBINATOR_TILDE) {
      // ~ combinator: match any preceding sibling
      return _matchesAnyPrecedingSibling(node, sequences, currentIndex - 1);
    }

    // No combinator or unknown combinator (shouldn't happen for valid CSS)
    return currentIndex == 0;
  }

  /// Check if any ancestor matches the remaining sequences
  bool _matchesAnyAncestor(
      XmlElement node,
      List<css.SimpleSelectorSequence> sequences,
      int sequenceIndex,
      ) {
    var current = node.parent;
    while (current is XmlElement) {
      if (_matchesSequences(current, sequences, sequenceIndex)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Check if any preceding sibling matches the remaining sequences
  bool _matchesAnyPrecedingSibling(
      XmlElement node,
      List<css.SimpleSelectorSequence> sequences,
      int sequenceIndex,
      ) {
    var current = _getPreviousSiblingElement(node);
    while (current != null) {
      if (_matchesSequences(current, sequences, sequenceIndex)) {
        return true;
      }
      current = _getPreviousSiblingElement(current);
    }
    return false;
  }

  /// Get the previous sibling element (skipping text nodes, etc.)
  XmlElement? _getPreviousSiblingElement(XmlElement node) {
    final parent = node.parent;
    if (parent is! XmlElement) return null;

    final siblings = parent.children.whereType<XmlElement>().toList();
    final index = siblings.indexOf(node);

    return index > 0 ? siblings[index - 1] : null;
  }

  /// Match a simple selector sequence (e.g., div.class#id[attr])
  bool _matchesSimpleSequence(
      XmlElement node,
      css.SimpleSelectorSequence sequence
      ) {
    final simpleSelector = sequence.simpleSelector;

    // Parse the selector text to extract classes, IDs, and attributes
    final selectorText = simpleSelector.toString();

    // Check element name (extract from beginning of selector before any . # [ :)
    final elementMatch = RegExp(r'^([a-zA-Z][\w-]*)').firstMatch(selectorText);
    if (elementMatch != null) {
      final elementName = elementMatch.group(1)!;
      if (elementName != '*' && elementName != node.name.local) {
        return false;
      }
    } else if (!selectorText.startsWith('*') &&
        !selectorText.startsWith('.') &&
        !selectorText.startsWith('#') &&
        !selectorText.startsWith('[') &&
        !selectorText.startsWith(':')) {
      // If there's no element selector and it doesn't start with a class/id/attr,
      // it might be malformed
      return false;
    }

    // Extract and check ID
    final idMatch = RegExp(r'#([\w-]+)').firstMatch(selectorText);
    if (idMatch != null) {
      if (node.getAttribute('id') != idMatch.group(1)) {
        return false;
      }
    }

    // Extract and check classes
    final classMatches = RegExp(r'\.([\w-]+)').allMatches(selectorText);
    for (var match in classMatches) {
      final className = match.group(1)!;
      final classes = node.getAttribute('class')?.split(' ') ?? [];
      if (!classes.contains(className)) {
        return false;
      }
    }

    // Extract and check attributes
    final attrMatches = RegExp(r'\[(\w+)(?:([~|^$*]?=)"?([^"\]]+)"?)?\]')
        .allMatches(selectorText);
    for (var match in attrMatches) {
      final attrName = match.group(1)!;
      final operator = match.group(2);
      final attrValue = match.group(3);

      final nodeAttrValue = node.getAttribute(attrName);

      if (operator == null) {
        // Just check attribute exists
        if (nodeAttrValue == null) return false;
      } else if (operator == '=') {
        if (nodeAttrValue != attrValue) return false;
      } else if (operator == '~=') {
        if (nodeAttrValue == null ||
            !nodeAttrValue.split(' ').contains(attrValue)) return false;
      } else if (operator == '|=') {
        if (nodeAttrValue == null ||
            (!nodeAttrValue.startsWith('$attrValue-') &&
                nodeAttrValue != attrValue)) return false;
      } else if (operator == '^=') {
        if (nodeAttrValue == null ||
            !nodeAttrValue.startsWith(attrValue!)) return false;
      } else if (operator == r'$=') {
        if (nodeAttrValue == null ||
            !nodeAttrValue.endsWith(attrValue!)) return false;
      } else if (operator == '*=') {
        if (nodeAttrValue == null ||
            !nodeAttrValue.contains(attrValue!)) return false;
      }
    }

    return true;
  }

  /// Calculate CSS specificity (a, b, c) where:
  /// a = number of ID selectors
  /// b = number of class selectors, attribute selectors, and pseudo-classes
  /// c = number of element selectors and pseudo-elements
  int _calculateSpecificity(css.Selector selector) {
    int ids = 0, classes = 0, elements = 0;

    for (var sequence in selector.simpleSelectorSequences) {
      final selectorText = sequence.simpleSelector.toString();

      // Count IDs
      ids += RegExp(r'#[\w-]+').allMatches(selectorText).length;

      // Count classes
      classes += RegExp(r'\.[\w-]+').allMatches(selectorText).length;

      // Count attributes
      classes += RegExp(r'\[[\w-]+').allMatches(selectorText).length;

      // Count pseudo-classes (but not pseudo-elements)
      classes += RegExp(r':(?!:)[\w-]+').allMatches(selectorText).length;

      // Count element selectors (extract from beginning of selector)
      final elementMatch = RegExp(r'^([a-zA-Z][\w-]*)').firstMatch(selectorText);
      if (elementMatch != null && elementMatch.group(1) != '*') {
        elements++;
      }

      // Count pseudo-elements
      elements += RegExp(r'::[\w-]+').allMatches(selectorText).length;
    }

    // Combine into single int: specificity = a*100 + b*10 + c
    return ids * 100 + classes * 10 + elements;
  }

  /// Helper to get a declaration value as string
  String? getDeclarationValue(
      Map<String, css.Expression> declarations,
      String property
      ) {
    final expr = declarations[property];
    return expr?.toString();
  }
}

class _RuleMatch {
  final css.RuleSet rule;
  final int specificity;

  _RuleMatch(this.rule, this.specificity);
}
