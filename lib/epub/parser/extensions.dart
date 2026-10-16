import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ordered_set/ordered_set.dart';
import 'package:xml/xml.dart';

import '../../models/manifest_item.dart';
import '../handlers/html_handler.dart';

typedef CssDeclarations = Map<String, String>;

// Some (older, admittedly) epub archives don't have reliably consistent filenames in the archive; so look for the value
// ending in what we are looking for and this should catch everything I've seen; so far, at least.
extension FindFileExtension on Archive {
  ArchiveFile? findFileEndsWith(String filename) {
    return files.firstWhere((file) => file.name.endsWith(Uri.decodeFull(filename).replaceAll('../', '')));
  }

  String getContentAsString(String filename) {
    ArchiveFile file = findFileEndsWith(filename)!;
    InputStream chapterStream = file.getContent()!;

    final String contents = chapterStream.readString();
    chapterStream.close();
    return contents;
  }

  Uint8List getContentAsBytes(String filename) {
    ArchiveFile file = findFileEndsWith(filename)!;
    return file.readBytes()!;
  }
}

const dcNamespace = 'http://purl.org/dc/elements/1.1/';
extension FileAuthorExtension on XmlDocument {
  String       get author => findAllElements('creator', namespaceUri: dcNamespace).firstOrNull?.innerText ?? "";
  String       get  title => findAllElements('title',   namespaceUri: dcNamespace).firstOrNull?.innerText ?? "";
  List<String> get  spine => findAllElements('itemref').map((el) => el.getAttribute('idref')!).toList();

  Map<String, ManifestItem> get manifest {
    Map<String, ManifestItem> manifest = {};
    for (var el in findAllElements('item')) {
      manifest[el.getAttribute('id')!] = ManifestItem(href: el.getAttribute('href')!, mimeType: el.getAttribute('media-type')!);
    }
    return manifest;
  }
}

extension NodeExtension on XmlNode {
  HtmlHandler? get handler {
    return switch (this) {
      XmlElement el => HtmlHandler.getHandler(el.name.local.toLowerCase()),
      XmlText     t => HtmlHandler.getHandler(t.nodeType.name.toLowerCase()),
                  _ => null,
    };
  }

  // We get a lot of blank lines in HTML which get processed as Nodes. We want to ignore these.
  // A text node is blank indentation only if it contains at least one newline; a bare space between spans is real content.
  bool get shouldProcess => !(this is XmlText && RegExp(r'^[\r\n ]*[\r\n][\r\n ]*$').hasMatch(value!));
}

// A <p> with no text and no child elements is just HTML source formatting whitespace, not a real paragraph.
bool isEmptyParagraph(XmlNode node) {
  if (node is XmlElement && node.localName == 'p') {
    // If there are child elements (not just text nodes), it's not empty
    if (node.children.any((child) => child is XmlElement)) {
      return false;
    }

    // Check if there's any text content or entities
    for (var child in node.children) {
      if (child is XmlText) {
        // Check the raw text (before entity decoding)
        if (child.value.trimPreservingNbsp().isNotEmpty) {
          return false;
        }
      }
    }

    return true;
  }

  return false;
}

extension SelectorSetExtension on XmlElement {
  OrderedSet<String> get selectorSet {
    OrderedSet<String> selectors = OrderedSet.simple<String>();

    final String? elementClasses = getAttribute("class");
    if (elementClasses != null) {
      if (hasParent && previousElementSibling != null) {
        for (var elementClass in previousElementSibling!.getAttribute("class")?.split(" ") ?? []) {
          selectors.add('$elementClass + $localName');
        }
      }

      for (var elementClass in elementClasses.split(" ")) {
        selectors.add(elementClass);
      }
    }

    return selectors;
  }
}
extension SelectorMapExtension on Map<String, CssDeclarations> {
  void combine(String selector, CssDeclarations declarations,) {
    if (containsKey(selector)) {
      this[selector] = { ...this[selector]!, ...declarations };
    } else {
      this[selector] = { ...declarations };
    }
  }
}

// In horizontal writing modes the logical margins are just other names for the physical ones, so whichever is
// declared later in the cascade has to replace the other rather than sit alongside it (BlockStyle adds the two
// together). Without this, a book's "margin: 0" can't cancel the margin-block-start/end that assets/default.css
// gives elements such as blockquote.
const Map<String, List<String>> _marginAliases = {
  'margin':              ['margin-top', 'margin-right', 'margin-bottom', 'margin-left',
                          'margin-block-start', 'margin-block-end', 'margin-inline-start', 'margin-inline-end'],
  'margin-top':          ['margin-block-start'],
  'margin-bottom':       ['margin-block-end'],
  'margin-left':         ['margin-inline-start'],
  'margin-right':        ['margin-inline-end'],
  'margin-block-start':  ['margin-top'],
  'margin-block-end':    ['margin-bottom'],
  'margin-inline-start': ['margin-left'],
  'margin-inline-end':   ['margin-right'],
};

/// Expands a CSS `margin` shorthand (one to four values) into its physical longhands.
Map<String, String> expandMarginShorthand(String margin) {
  final List<String> parts = margin.trim().split(RegExp(r'\s+'));
  final (String top, String right, String bottom, String left) = switch (parts.length) {
    1 => (parts[0], parts[0], parts[0], parts[0]),
    2 => (parts[0], parts[1], parts[0], parts[1]),
    3 => (parts[0], parts[1], parts[2], parts[1]),
    _ => (parts[0], parts[1], parts[2], parts[3]),
  };

  return {'margin-top': top, 'margin-right': right, 'margin-bottom': bottom, 'margin-left': left};
}

extension CssDeclarationsExtension on CssDeclarations {
  CssDeclarations combine(CssDeclarations? declarations,) {
    final CssDeclarations result = {...this};
    for (final String property in declarations?.keys ?? const <String>[]) {
      if (!_marginAliases.containsKey(property)) continue;

      // A longhand can only replace one side of an earlier shorthand once the shorthand is split into its sides.
      // Longhands already present were declared after the shorthand, so they keep their values.
      final String? shorthand = property != 'margin' ? result.remove('margin') : null;
      if (shorthand != null) {
        expandMarginShorthand(shorthand).forEach((side, value) => result.putIfAbsent(side, () => value));
      }
      _marginAliases[property]!.forEach(result.remove);
    }

    return {
        ...result,
        ...?declarations,
    };
  }
}

extension WhitespaceTrimExtension on String {
  /// Trims all whitespace except non-breaking spaces (U+00A0)
  String trimPreservingNbsp() {
    if (isEmpty) return this;

    // Non-breaking space character
    const nbsp = '\u00A0';

    int start = 0;
    int end = length;

    // Trim from start
    while (start < end) {
      final char = this[start];
      if (char == nbsp || char.trim().isNotEmpty) {
        break;
      }
      start++;
    }

    // Trim from end
    while (end > start) {
      final char = this[end - 1];
      if (char == nbsp || char.trim().isNotEmpty) {
        break;
      }
      end--;
    }

    return substring(start, end);
  }
}

extension RemoveContiguousDuplicates<T> on List<T> {
  List<T> removeContiguousDuplicates() {
    if (isEmpty) return [];
    return fold<List<T>>(
      [],
          (result, item) => result.isEmpty || result.last != item
          ? [...result, item]
          : result,
    );
  }
}

extension StringFootnotes on String {
  bool get isFootnote {
    if (isEmpty) return false;

    final allAsterisks = !RegExp(r'[^\*]').hasMatch(this);
    if (allAsterisks) return true;

    final allCrosses = !RegExp(r'[^\†]').hasMatch(this);
    if (allCrosses) return true;
    
    final allDigits = !RegExp(r'[^0-9]').hasMatch(this);
    if (allDigits) return true;

    final fnIndicator = RegExp(r'fn[0-9]+').hasMatch(this);
    return fnIndicator;
  }
}

extension SplitReference on String {
  (String, String) get splitReference {
    if (contains("#")) {
      List<String> splitRef = split('#');
      return (splitRef.first, splitRef.last);
    }

    return ("", "");
  }
}




