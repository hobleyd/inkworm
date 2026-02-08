import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkworm/epub/structure/epub_chapter.dart';
import 'package:inkworm/epub/elements/separators/non_breaking_space_separator.dart';
import 'package:inkworm/epub/handlers/block_handler.dart';
import 'package:inkworm/epub/handlers/css_handler.dart';
import 'package:inkworm/epub/handlers/image_handler.dart';
import 'package:inkworm/epub/handlers/inline_handler.dart';
import 'package:inkworm/epub/handlers/line_break_handler.dart';
import 'package:inkworm/epub/handlers/link_handler.dart';
import 'package:inkworm/epub/handlers/superscript_handler.dart';
import 'package:inkworm/epub/handlers/text_handler.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';
import 'package:inkworm/models/page_size.dart';
import 'package:inkworm/epub/content/text_content.dart';
import 'package:inkworm/epub/elements/separators/hyphen_separator.dart';
import 'package:inkworm/epub/elements/separators/space_separator.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/providers/epub.dart';
import 'package:inkworm/epub/structure/build_line.dart';
import 'package:inkworm/epub/structure/build_page.dart';
import 'package:inkworm/epub/structure/line.dart';
import 'package:inkworm/epub/structure/page.dart';
import 'package:inkworm/epub/elements/word_element.dart';
import 'package:inkworm/epub/styles/block_style.dart';
import 'package:inkworm/epub/styles/element_style.dart';
import 'package:inkworm/models/reading_progress.dart';
import 'package:mockito/annotations.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([Line, WordElement, SpaceSeparator, Epub,])
void main() {
    late BuildPage buildPage;
    late BuildLine buildLine;
    late TextStyle style;
    late BlockStyle blockStyle;
    late ThemeData themeData;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      GetIt.instance.registerSingleton<CssParser>(CssParser());
      GetIt.instance.registerSingleton<PageSize>(PageSize());
      GetIt.instance.registerSingleton<ReadingProgress>(ReadingProgress());
      GetIt.instance.registerSingleton<EpubParser>(EpubParser());
      GetIt.instance.registerSingleton<BuildPage>(BuildPage());
      GetIt.instance.registerSingleton<BuildLine>(BuildLine());
      GetIt.instance.registerSingleton<BlockHandler>(BlockHandler());
      GetIt.instance.registerSingleton<TextHandler>(TextHandler());
      GetIt.instance.registerSingleton<LineBreakHandler>(LineBreakHandler());
      GetIt.instance.registerSingleton<InlineHandler>(InlineHandler());
      GetIt.instance.registerSingleton<LinkHandler>(LinkHandler());
      GetIt.instance.registerSingleton<ImageHandler>(ImageHandler());
      GetIt.instance.registerSingleton<SuperscriptHandler>(SuperscriptHandler());
      GetIt.instance.registerSingleton<CssHandler>(CssHandler());

      buildPage = GetIt.instance.get<BuildPage>();
      buildLine = GetIt.instance.get<BuildLine>();
      buildLine.lineListener = buildPage;

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

      style = themeData.textTheme.bodySmall!;
      blockStyle = BlockStyle(elementStyle: ElementStyle());
      blockStyle.elementStyle.textStyle = style;
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    group('constructor', () {
      test('should initialize with empty lines and footnotes', () {
        final Page page = Page();
        expect(page.lines, isEmpty);
        expect(page.footnotes, isEmpty);
      });
    });

    group('addText', () {
      test('check for lines, words and separators', () {
        final TextContent content = TextContent(
          blockStyle: blockStyle,
          elementStyle: blockStyle.elementStyle,
          text: """The cutter passed from sunlit brilliance to soot-black shadow with the knife-edge suddenness possible only in space, and the tall, broad-shouldered woman in the black and gold of the Royal Manticoran Navy gazed out the armorplast port at the battle-steel beauty of her command and frowned.""",
        );

        for (final el in content.elements) {
          buildLine.addElement(el);
        }
        buildLine.completeParagraph();

        final List<Line> lines = buildPage.lines;
        expect(lines.length, greaterThan(1));
        expect(lines.first.yPosOnPage, 0);
        expect(lines.first.textIndent, 0);

        final List elements = lines.expand((line) => line.elements).toList();
        expect(elements.whereType<WordElement>().length, greaterThan(0));
        expect(elements.whereType<SpaceSeparator>().length, greaterThan(0));
        expect(elements.whereType<HyphenSeparator>().length, greaterThan(0));

        for (int i = 1; i < lines.length; i++) {
          expect(lines[i].yPosOnPage, greaterThan(lines[i - 1].yPosOnPage));
          expect(lines[i].textIndent, 0);
        }

        expect(lines.last.alignment, LineAlignment.left);
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

        final bool hasNbspLine = chapter.pages[0].lines.any(
          (line) => line.elements.whereType<NonBreakingSpaceSeparator>().isNotEmpty,
        );
        expect(hasNbspLine, isTrue);
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
        expect(chapter.pages[0].lines.length, greaterThan(10));

        final List<Line> lines = chapter.pages[0].lines;
        for (int i = 1; i < lines.length; i++) {
          expect(lines[i].yPosOnPage, greaterThan(lines[i - 1].yPosOnPage));
        }
      });
    });

}
