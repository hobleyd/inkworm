import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../models/manifest_item.dart';

// Some (older, admittedly) epub archives don't have reliably consistent filenames in the archive; so look for the value
// ending in what we are looking for and this should catch everything I've seen; so far, at least.
extension FindFileExtension on Archive {
  ArchiveFile? findFileEndsWith(String filename) {
    return files.firstWhere((file) => file.name.endsWith(Uri.decodeFull(filename)));
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

