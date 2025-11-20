import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../elements/epub_chapter.dart';
import '../content/html_content.dart';
import 'extensions.dart';

@Singleton()
class EpubParser {
  late Archive bookArchive;

  EpubParser();

  Uint8List getBytes(String path) {
    return bookArchive.getContentAsBytes(path);
  }

  XmlDocument? getOPFContent(String opfPath) {
    return XmlDocument.parse(bookArchive.getContentAsString(opfPath));
  }

  String? getOPFPath() {
    // We need to check twice, because while most epubs have a single META_INF/container.xml in the root of the Archive,
    // some have it in a sub folder and so _findFileInArchive is required. We can't just search for it that way though
    // because other archives have multiple containers and we need to preference the top level one.
    ArchiveFile? container = bookArchive.find('META-INF/container.xml');
    container ??= bookArchive.findFileEndsWith('META-INF/container.xml');

    InputStream? containerStream = container?.getContent();
    if (containerStream == null) {
      return null;
    }

    final XmlDocument document = XmlDocument.parse(containerStream.readString());
    XmlElement? rootfile = document.findAllElements('rootfile').firstOrNull;

    containerStream.close();
    return rootfile?.getAttributeNode("full-path")?.value;
  }

  void openBook(String uri) {
    final inputStream = InputFileStream(uri);
    bookArchive = ZipDecoder().decodeStream(inputStream);
    inputStream.close();
  }

  XmlDocument parse() {
    String? opfPath = getOPFPath();
    if (opfPath == null) {
      throw FormatException("No OPF path registered in epub");
    }

    XmlDocument? opf = getOPFContent(opfPath);
    if (opf == null) {
      throw FormatException("No OPF file registered in epub");
    }

    return opf;
  }

  Future<EpubChapter> parseChapter(int index, String href) async {
    EpubChapter chapter = EpubChapter(chapterNumber: index);

    final XmlDocument doc = XmlDocument.parse(bookArchive.getContentAsString(href));

    if (index == 2) {
      debugPrint('here');
    }
    for (final XmlNode node in doc.children) {
      List<HtmlContent>? elements = await node.handler?.processElement(node: node,);
      if (elements != null) {
        for (var el in elements) {
          chapter.addContentToCurrentPage(el);
        }
      }
    }

    return chapter;
  }
}