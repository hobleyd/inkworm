import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'epub_parser.dart';

@Singleton()
class FontManagement {
  Set<String> verifiedFonts = {};

  Future<void> loadFontFromEpub(String fontFamily, Uint8List fontBytes) async {
    if (!verifiedFonts.contains(fontFamily)) {
      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();

      verifiedFonts.add(fontFamily);
    }
  }

}