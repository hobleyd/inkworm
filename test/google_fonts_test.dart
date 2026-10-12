import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const String text = 'The quick brown fox jumps over the lazy dog';

double widthOf(String text, TextStyle style) {
  final TextPainter painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Gentium Book Plus has to come out of assets/google_fonts/; a test that quietly downloaded it would prove
    // nothing about the bundled copy, and google_fonts throws rather than fetching once this is off.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('every Gentium Book Plus variant is bundled under the name google_fonts looks for', () async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    // google_fonts matches a bundled font on its file name alone, so a renamed file is silently ignored.
    expect(
      manifest.listAssets(),
      containsAll([
        'assets/google_fonts/GentiumBookPlus-Regular.ttf',
        'assets/google_fonts/GentiumBookPlus-Italic.ttf',
        'assets/google_fonts/GentiumBookPlus-Bold.ttf',
        'assets/google_fonts/GentiumBookPlus-BoldItalic.ttf',
      ]),
    );
  });

  test('the theme font family is the bundled regular face', () {
    // lib/providers/theme.dart hands this name to ThemeData.fontFamily.
    expect(GoogleFonts.gentiumBookPlus().fontFamily, 'GentiumBookPlus_regular');
  });

  test('every Gentium Book Plus variant loads from the bundled assets', () async {
    final List<TextStyle> styles = [
      GoogleFonts.gentiumBookPlus(),
      GoogleFonts.gentiumBookPlus(fontStyle: FontStyle.italic),
      GoogleFonts.gentiumBookPlus(fontWeight: FontWeight.w700),
      GoogleFonts.gentiumBookPlus(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
    ];

    // Completes with an error if any variant could not be read from the asset bundle.
    await GoogleFonts.pendingFonts();

    expect(styles.map((style) => style.fontFamily), [
      'GentiumBookPlus_regular',
      'GentiumBookPlus_italic',
      'GentiumBookPlus_700',
      'GentiumBookPlus_700italic',
    ]);
  });

  test('text set in Gentium Book Plus is laid out with its own glyphs', () async {
    final TextStyle regular = GoogleFonts.gentiumBookPlus(fontSize: 20);
    final TextStyle italic = GoogleFonts.gentiumBookPlus(fontSize: 20, fontStyle: FontStyle.italic);
    final TextStyle bold = GoogleFonts.gentiumBookPlus(fontSize: 20, fontWeight: FontWeight.w700);
    final TextStyle boldItalic = GoogleFonts.gentiumBookPlus(fontSize: 20, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic);
    await GoogleFonts.pendingFonts();

    // A family that never loaded falls back to the test font, where every glyph is one em square - so equal
    // widths for "i" and "M" are what a font that failed to load looks like.
    const TextStyle unloaded = TextStyle(fontFamily: 'NoSuchFont', fontSize: 20);
    expect(widthOf('iiiiiiiiii', unloaded), widthOf('MMMMMMMMMM', unloaded));
    expect(widthOf(text, unloaded), text.length * 20);

    for (final TextStyle style in [regular, italic, bold, boldItalic]) {
      expect(widthOf('iiiiiiiiii', style), lessThan(widthOf('MMMMMMMMMM', style)), reason: '${style.fontFamily} is not proportional');
      expect(widthOf(text, style), lessThan(text.length * 20), reason: '${style.fontFamily} fell back to the test font');
    }

    // Each variant is a face of its own rather than the regular one reused.
    expect({for (final TextStyle style in [regular, italic, bold, boldItalic]) widthOf(text, style)}, hasLength(4));
  });
}
