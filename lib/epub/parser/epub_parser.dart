import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../structure/epub_chapter.dart';
import '../content/html_content.dart';
import 'extensions.dart';

@Singleton()
class EpubParser {
  Archive? bookArchive;
  XmlDocument? opf;
  int currentChapterIndex = -1;

  EpubParser();

  Uint8List getBytes(String path) {
    return bookArchive!.getContentAsBytes(path);
  }

  XmlElement? getFootnote(String path, String id) {
    final document = getXmlDocument(path);
    if (document != null) {
      XmlElement? note = document.findAllElements('*').firstWhereOrNull((element) => element.getAttribute('id') == id,);

      if (note != null) {
        // TODO: more testing required for different types of Footnotes. This works for Babel!
        // It will retrieve siblings of footnotes for where there are mutiple blocks of text.
        if (note.hasParent && note.parentElement!.name.local == 'p') {
          XmlElement parent = note.parentElement!;
          if (parent.hasParent && parent.parentElement!.name.local == 'section') {
            return parent.parentElement;
          }

          return parent;
        }
        return note;
      }

    }

    return null;
}

  XmlDocument? getXmlDocument(String path) {
    try {
      return XmlDocument.parse(bookArchive!.getContentAsString(path));
    } catch (e) {
      // Normally references to online Web pages from what I can see. Why would you do that?
      return null;
    }
  }

  String? getOPFPath() {
    // We need to check twice, because while most epubs have a single META_INF/container.xml in the root of the Archive,
    // some have it in a sub folder and so _findFileInArchive is required. We can't just search for it that way though
    // because other archives have multiple containers and we need to preference the top level one.
    ArchiveFile? container = bookArchive!.find('META-INF/container.xml');
    container ??= bookArchive!.findFileEndsWith('META-INF/container.xml');

    InputStream? containerStream = container?.getContent();
    if (containerStream == null) {
      return null;
    }

    final XmlDocument document = XmlDocument.parse(containerStream.readString());
    XmlElement? rootfile = document.findAllElements('rootfile').firstOrNull;

    containerStream.close();
    return rootfile?.getAttributeNode("full-path")?.value;
  }

  XmlDocument getOPF() {
    if (opf != null) {
      return opf!;
    }

    String? opfPath = getOPFPath();
    if (opfPath == null) {
      throw FormatException("No OPF path registered in epub");
    }

    opf = getXmlDocument(opfPath);
    if (opf == null) {
      throw FormatException("No OPF file registered in epub");
    }

    return opf!;
  }

  void openBook(String book) {
    final inputStream = InputFileStream(book);
    bookArchive = ZipDecoder().decodeStream(inputStream);
    inputStream.close();
  }

  Future<EpubChapter> parseChapter(int index, String href) async {
    currentChapterIndex = index;
    EpubChapter chapter = EpubChapter(chapterNumber: index);

    return await parseChapterFromString(chapter, bookArchive!.getContentAsString(href));
  }

  // Returns the spine position of the given filename, or null if not found or the OPF is unavailable.
  int? spineIndexForFile(String filename) {
    try {
      final opfDoc = getOPF();
      final manifest = opfDoc.manifest;
      final spine = opfDoc.spine;

      final entry = manifest.entries.firstWhereOrNull(
        (e) => e.value.href.endsWith(filename) || e.value.href == filename,
      );
      if (entry == null) return null;

      final idx = spine.indexOf(entry.key);
      return idx >= 0 ? idx : null;
    } catch (_) {
      return null;
    }
  }

  Future<EpubChapter> parseChapterFromString(EpubChapter chapter, String chapterText) async {
    final XmlDocument doc = XmlDocument.parse(chapterText);
    for (final XmlNode node in doc.children) {
      if (node.shouldProcess) {
        final List<HtmlContent>? elements = await node.handler?.processElement(node: node,);
        if (elements != null) {
          chapter.addContent(elements);
        }
      }
    }

    return chapter;
  }
}