import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

@Singleton()
class FontManagement {
  Set<String> verifiedFonts = {};

  // A font-family can have several @font-face variants (regular, italic, bold, bold-italic, ...), each
  // with its own src. Track "already loaded" per family+src, not per family alone - otherwise the first
  // variant encountered (e.g. italic) is registered and every other variant of the same family (e.g.
  // regular) is silently skipped, leaving Flutter with only the first face for the whole family.
  Future<void> loadFontFromEpub(String fontFamily, String fontSource, Uint8List fontBytes) async {
    final String key = '$fontFamily::$fontSource';
    if (!verifiedFonts.contains(key)) {
      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();

      verifiedFonts.add(key);
    }
  }

}