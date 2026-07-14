import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkworm/epub/parser/font_management.dart';

void main() {
  test('loads every @font-face variant of a family, not just the first one encountered', () async {
    // Regression test for "Machine" by Elizabeth Bear: 9781534403031.css declares "EB Garamond" twice -
    // an italic @font-face first, then a normal one. FontManagement used to track "already loaded" per
    // family name alone, so once the italic variant was registered with Flutter's FontLoader, the normal
    // variant was silently skipped - leaving every non-italic use of "EB Garamond" (e.g. the "ded" class
    // used by dedication.xhtml's "For Chelsea") rendering in italics, since that was the only face ever
    // actually loaded for the family.
    TestWidgetsFlutterBinding.ensureInitialized();

    final FontManagement fontManagement = FontManagement();

    await fontManagement.loadFontFromEpub('EB Garamond', '../Fonts/EBGaramond-Italic.ttf', Uint8List(4));
    await fontManagement.loadFontFromEpub('EB Garamond', '../Fonts/EBGaramond-Regular.ttf', Uint8List(4));

    expect(fontManagement.verifiedFonts, hasLength(2));
  });

  test('does not reload the same font-face variant twice', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final FontManagement fontManagement = FontManagement();

    await fontManagement.loadFontFromEpub('EB Garamond', '../Fonts/EBGaramond-Regular.ttf', Uint8List(4));
    await fontManagement.loadFontFromEpub('EB Garamond', '../Fonts/EBGaramond-Regular.ttf', Uint8List(4));

    expect(fontManagement.verifiedFonts, hasLength(1));
  });
}
