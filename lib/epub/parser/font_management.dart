import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'epub_parser.dart';

@Singleton()
class FontManagement {
  Set<String> verifiedFonts = {};

  Future<void> loadFontFromEpub(String fontFamily, String fontPath) async {
    // Knowing how the getBytes function works, strip out the relative paths as they won't be needed. Purists will disagree ;-)
    String cleanedPath = fontPath.replaceAll(RegExp(r'^(\.\.\/)+'), '');

    final bytes = GetIt.instance.get<EpubParser>().getBytes(cleanedPath);

    final fontLoader = FontLoader(fontFamily);
    fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();

    verifiedFonts.add(fontFamily);
  }

}