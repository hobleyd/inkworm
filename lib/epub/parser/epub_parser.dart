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

  EpubParser();

  Uint8List getBytes(String path) {
    return bookArchive!.getContentAsBytes(path);
  }

  XmlElement? getFootnote(String href) {
    List<String> hrefDetails = href.split('#');
    String path = hrefDetails.first;
    String id = hrefDetails.last;
    
    final document = getXmlDocument(path);
    if (document != null) {
      return document.findAllElements('*').firstWhereOrNull((element) => element.getAttribute('id') == id,);
    }

    return null;
}

  XmlDocument? getXmlDocument(String path) {
    return XmlDocument.parse(bookArchive!.getContentAsString(path));
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
    String? opfPath = getOPFPath();
    if (opfPath == null) {
      throw FormatException("No OPF path registered in epub");
    }

    XmlDocument? opf = getXmlDocument(opfPath);
    if (opf == null) {
      throw FormatException("No OPF file registered in epub");
    }

    return opf;
  }

  Future<EpubChapter> parseChapter(int index, String href) async {
    EpubChapter chapter = EpubChapter(chapterNumber: index);

    return parseChapterFromString(chapter, bookArchive!.getContentAsString(href));
  }

  Future<EpubChapter> parseChapterFromString(EpubChapter chapter, String chapterText) async {
    final XmlDocument doc = XmlDocument.parse(chapterText);
    for (final XmlNode node in doc.children) {
      if (node.shouldProcess) {
        final List<HtmlContent>? elements = await node.handler?.processElement(node: node,);
        chapter.addContent(elements!);
      }
    }

    return chapter;
  }
}