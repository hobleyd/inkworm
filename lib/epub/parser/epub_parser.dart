import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../epub_chapter.dart';
import 'extensions.dart';

class EpubParser {
  late Archive bookArchive;

  EpubParser();

  XmlDocument? getOPFContent(String opfPath) {
    InputStream? opf = bookArchive.findFileEndsWith(opfPath)?.getContent();
    if (opf == null) {
      return null;
    }

    return XmlDocument.parse(opf.readString());
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

    return rootfile?.getAttributeNode("full-path")?.value;
  }

  void openBook() {
    String bookPath = Platform.environment['EBOOK']!;
    final inputStream = InputFileStream(bookPath);
    bookArchive = ZipDecoder().decodeStream(inputStream);
    inputStream.closeSync();
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

  EpubChapter parseChapter(int index, String href) {
    EpubChapter chapter = EpubChapter(chapterNumber: index);
    ArchiveFile file = bookArchive.findFileEndsWith(href)!;
    InputStream chapterStream = file.getContent()!;

    final XmlDocument doc = XmlDocument.parse(chapterStream.readString());
    for (final node in doc.children) {
      debugPrint('$node');
    }

    return chapter;
  }
}