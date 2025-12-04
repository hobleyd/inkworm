import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkworm/epub/elements/epub_chapter.dart';
import 'package:inkworm/epub/elements/separators/non_breaking_space_separator.dart';
import 'package:inkworm/epub/handlers/block_handler.dart';
import 'package:inkworm/epub/handlers/line_break_handler.dart';
import 'package:inkworm/epub/handlers/text_handler.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';
import 'package:inkworm/models/page_size.dart';
import 'package:inkworm/epub/content/text_content.dart';
import 'package:inkworm/epub/elements/separators/hyphen_separator.dart';
import 'package:inkworm/epub/elements/separators/space_separator.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/providers/epub.dart';
import 'package:inkworm/epub/elements/line.dart';
import 'package:inkworm/epub/elements/word_element.dart';
import 'package:inkworm/epub/elements/epub_page.dart';
import 'package:inkworm/epub/styles/block_style.dart';
import 'package:inkworm/epub/styles/element_style.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([Line, WordElement, SpaceSeparator, Epub,])
void main() {
    late EpubPage epubPage;
    late TextStyle style;
    late BlockStyle blockStyle;
    late ThemeData themeData;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      GetIt.instance.registerSingleton<CssParser>(CssParser());
      GetIt.instance.registerSingleton<PageSize>(PageSize());
      GetIt.instance.registerSingleton<EpubParser>(EpubParser());
      GetIt.instance.registerSingleton<BlockHandler>(BlockHandler());
      GetIt.instance.registerSingleton<TextHandler>(TextHandler());
      GetIt.instance.registerSingleton<LineBreakHandler>(LineBreakHandler());

      epubPage = EpubPage();

      PageSize size = GetIt.instance.get<PageSize>();
      size.canvasHeight = 80;
      size.canvasWidth = 378;
      size.pixelDensity = 1;
      size.leftIndent = 12;
      size.rightIndent = 12;

      themeData = ThemeData(
        colorSchemeSeed: Colors.white,
        fontFamily: GoogleFonts.gentiumBookPlus().fontFamily,
        inputDecorationTheme: const InputDecorationTheme(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2))),
        textTheme: TextTheme(
          titleSmall: TextStyle(fontSize: 12 - 2, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(fontSize: 12 + 1, fontWeight: FontWeight.w400),
          labelMedium: TextStyle(fontSize: 12 + 1, fontWeight: FontWeight.w700),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black),
          labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          selectionHandleColor: Color(0xf0e8e4df),
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
      );
    });

    testWidgets('Test Theme in Widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          home: Scaffold(
            appBar: AppBar(),
            body: Builder(
              builder: (context) {
                // Access the theme here
                style = Theme.of(context).textTheme.bodySmall!;
                blockStyle = BlockStyle(elementStyle: ElementStyle());
                blockStyle.elementStyle.textStyle = style;
                return Container();
              },
            ),
          ),
        ),
      );
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    group('constructor', () {
      test('should initialize with empty lines and overflow lists', () {
        expect(epubPage.lines, isEmpty);
        expect(epubPage.overflow, isEmpty);
      });
    });

    group('addText', () {
      test('check for lines, words and separators', () {
        epubPage.addLine(paragraph: true, margin: 0, blockStyle: blockStyle,);

        epubPage.addElement(
            TextContent(
              blockStyle: blockStyle,
              elementStyle: blockStyle.elementStyle,
              text: """The cutter passed from sunlit brilliance to soot-black shadow with the knife-edge suddenness possible only in space, and the tall, broad-shouldered woman in the black and gold of the Royal Manticoran Navy gazed out the armorplast port at the battle-steel beauty of her command and frowned.""",
            ), []);

        epubPage.lines.last.completeParagraph();
        epubPage.lines.last.completeLine();

        Map<Type, int> line0 = groupBy(epubPage.lines[0].elements, (e) => e.runtimeType).map((k, v) => MapEntry(k, v.length));

        expect(epubPage.lines.length, 5);
        expect(epubPage.lines[0].yPos, 0);
        expect(epubPage.lines[0].textIndent, 18);
        expect(line0[(WordElement)], 11);
        expect(line0[(SpaceSeparator)], 9);
        expect(line0[(HyphenSeparator)], 1);
        expect(epubPage.lines[1].yPos, 16);
        expect(epubPage.lines[1].textIndent, 0);
        expect(epubPage.lines[2].yPos, 32);
        expect(epubPage.lines[2].textIndent, 0);
        expect(epubPage.lines[3].yPos, 48);
        expect(epubPage.lines[3].textIndent, 0);
        expect(epubPage.lines[4].yPos, 64);
        expect(epubPage.lines[4].textIndent, 0);
        expect(epubPage.lines[4].alignment, LineAlignment.left);

        epubPage.addElement(
            TextContent(
              blockStyle: blockStyle,
              elementStyle: blockStyle.elementStyle,
              text: """The six-limbed cream-and-gray treecat on her shoulder shifted his balance as she raised her right hand and pointed.""",
            ), []);

        expect(epubPage.overflow.length, 1);
      });
    });

    group('blank paragraph', () {
      test('check single blank paragraph', () async {
        EpubChapter chapter = EpubChapter(chapterNumber: 0);

        PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 600;
        EpubParser parser = GetIt.instance.get<EpubParser>();
        await parser.parseChapterFromString(chapter, '''<html><body>
<p>"I <i>do</i> see," he said in a very different tone. "And I think we should get Lady Harrington and Commodore McKeon in on this ASAP."</p>
<p>&#160;</p>
<p>"My, my, my," Honor said softly, gazing at a hardcopy of the data Tremaine had found. "How very convenient .&#160;.&#160;. maybe."</p>
</body></html>''');

        expect(chapter.pages.length, 1);
        expect(chapter.pages[0].lines[5].elements[0], isA<NonBreakingSpaceSeparator>());
    });
    });

    group('blank paragraph', () {
      test('check single blank paragraph', () async {
        EpubChapter chapter = EpubChapter(chapterNumber: 0);

        PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 600;
        EpubParser parser = GetIt.instance.get<EpubParser>();
        await parser.parseChapterFromString(chapter, '<html><body><h2 align="center"><b>ECHOES OF HONOR</b><br/><b>David Weber</b></h2><blockquote><p class="calibre_class_0">&#160;<br/>This is a work of fiction. All the characters and events portrayed in this book are fictional, and any resemblance to real people or incidents is purely coincidental.<br/><br/>Copyright © 1998 by David M. Weber<br/><br/>All rights reserved, including the right to reproduce this book or portions thereof in any form.</p></blockquote></body></html>');

        expect(chapter.pages.length, 1);
        expect(chapter.pages[0].lines.length, 18);
        expect(chapter.pages[0].lines[10].yPos, 80);
        expect(chapter.pages[0].lines[12].yPos, 104);
      });
    });

}