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
    return files.firstWhere((file) => file.name.endsWith(Uri.decodeFull(filename)));
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
  String get author => findAllElements('creator', namespace: dcNamespace).firstOrNull?.innerText ?? "";

  String get title => findAllElements('title', namespace: dcNamespace).firstOrNull?.innerText ?? "";

  List<String> get spine => findAllElements('itemref').map((el) => el.getAttribute('idref')!).toList();

  Map<String, ManifestItem> get manifest {
    Map<String, ManifestItem> manifest = {};
    for (var el in findAllElements('item')) {
      manifest[el.getAttribute('id')!] = ManifestItem(href: el.getAttribute('href')!, mimeType: el.getAttribute('media-type')!);
    }
    return manifest;
  }
}

extension HandlerNodeExtension on XmlNode {
  HtmlHandler? get handler {
    return switch (this) {
      XmlElement el => HtmlHandler.getHandler(el.name.local.toLowerCase()),
      XmlText     t => HtmlHandler.getHandler(t.nodeType.name.toLowerCase()),
                  _ => null,
    };
  }
}

extension SelectorSetExtension on XmlElement {
  OrderedSet<String> get selectorSet {
    OrderedSet<String> selectors = OrderedSet.simple<String>();

    final String? elementClasses = getAttribute("class");
    if (elementClasses != null) {
      for (var elementClass in elementClasses.split(" ")) {
        selectors.add(elementClass);
      }
    }

    return selectors;
  }
}
extension SelectorMapExtension on Map<String, CssDeclarations> {
  Map<String, CssDeclarations> combine(String selector, CssDeclarations declarations,) {
    final existingMap = this[selector];

    if (existingMap != null) {
      return {
        ...this,
        selector: {...existingMap, ...declarations}, };
    } else {
      return {
        ...this,
        selector: declarations,
      };
    }
  }
}

extension CssDeclarationsExtension on CssDeclarations {
  CssDeclarations combine(CssDeclarations? declarations,) {
    return {
        ...this,
        if (declarations != null) ...declarations,
    };
  }
}




