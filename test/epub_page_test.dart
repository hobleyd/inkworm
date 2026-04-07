import 'dart:isolate';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkworm/epub/cache/text_cache.dart';
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
import 'package:inkworm/epub/parser/isolates/worker_slot.dart';
import 'package:inkworm/providers/epub.dart';
import 'package:inkworm/epub/structure/build_line.dart';
import 'package:inkworm/epub/structure/build_page.dart';
import 'package:inkworm/epub/structure/line.dart';
import 'package:inkworm/epub/structure/page.dart';
import 'package:inkworm/models/element_size.dart';
import 'package:inkworm/epub/elements/word_element.dart';
import 'package:inkworm/epub/styles/block_style.dart';
import 'package:inkworm/epub/styles/element_style.dart';
import 'package:inkworm/models/reading_progress.dart';
import 'package:mockito/annotations.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([Line, WordElement, SpaceSeparator, Epub,])
void main() {
    ElementSize measureText(String text, TextStyle style, PageSize size) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      );
      painter.layout(maxWidth: size.canvasWidth - size.leftIndent - size.rightIndent);
      final LineMetrics metrics = painter.computeLineMetrics().first;
      final ElementSize result = ElementSize(
        ascent: metrics.ascent,
        descent: metrics.descent,
        height: painter.height,
        width: painter.width,
      );
      painter.dispose();
      return result;
    }

    List<String> splitText(String span) {
      final List<String> result = [];
      String current = "";

      for (int i = 0; i < span.length; i++) {
        final String char = span[i];

        if (char == '-' || char == '\u{2014}' || char == ' ' || char == '\u{00A0}') {
          if (current.isNotEmpty) {
            result.add(current);
            current = "";
          }
          result.add(char);
        } else {
          current += char;
        }
      }

      if (current.isNotEmpty) {
        result.add(current);
      }

      return result;
    }

    TextContent buildTextContent({
      required String text,
      required BlockStyle blockStyle,
      required PageSize size,
      TextStyle? textStyle,
      bool isDropCaps = false,
    }) {
      final ElementStyle elementStyle = ElementStyle();
      elementStyle.textStyle = textStyle ?? blockStyle.elementStyle.textStyle;
      elementStyle.isDropCaps = isDropCaps;

      final ElementSize textSize = measureText(text, elementStyle.textStyle, size);
      return TextContent(
        blockStyle: blockStyle,
        elementStyle: elementStyle,
        ascent: textSize.ascent,
        descent: textSize.descent,
        height: textSize.height,
        width: textSize.width,
        text: text,
      );
    }

    String lineText(Line line) {
      return line.elements.map((element) {
        if (element is WordElement) {
          return element.word.text;
        }

        final dynamic htmlElement = element.element;
        if (htmlElement is TextContent) {
          return htmlElement.text;
        }

        return '';
      }).join();
    }

    late BuildPage buildPage;
    late BuildLine buildLine;
    late TextStyle style;
    late BlockStyle blockStyle;
    late ThemeData themeData;
    late ReceivePort uiPort;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      GetIt.instance.registerSingleton<CssParser>(CssParser());
      GetIt.instance.registerSingleton<PageSize>(PageSize());
      GetIt.instance.registerSingleton<ReadingProgress>(ReadingProgress());
      GetIt.instance.registerSingleton<EpubParser>(EpubParser());
      GetIt.instance.registerSingleton<TextCache>(TextCache());
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

      uiPort = ReceivePort();
      uiPort.listen((dynamic request) {
        request.process(uiPort.sendPort);
      });
      WorkerSlot.staticUIPort = uiPort.sendPort;

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
      uiPort.close();
      WorkerSlot.staticUIPort = null;
      GetIt.instance.reset();
    });

    group('constructor', () {
      test('should initialize with empty lines and footnotes', () {
        final Page page = Page();
        expect(page.lines, isEmpty);
        expect(page.footnotes, isEmpty);
      });
    });

    group('pagination', () {
      test('uses max line height when checking if content fits on the page', () {
        final Page page = Page();
        page.pageHeight = 80;
        page.currentBottomYPos = 70;

        final Line line = Line();
        line.height = 10;
        line.maxHeight = 20;

        expect(line.lineHeight, 10);
        expect(line.maxLineHeight, 20);
        expect(page.willFitHeight(line), isFalse);
      });

      test('re-bases drop caps height when moving content to a new page', () {
        buildPage.currentPage.pageHeight = 80;
        buildPage.currentPage.currentBottomYPos = 30;
        buildPage.currentPage.dropCapsXPosition = 18;
        buildPage.currentPage.dropCapsYPosition = 54;

        buildPage.addPage();

        expect(buildPage.currentPage.dropCapsXPosition, 18);
        expect(buildPage.currentPage.dropCapsYPosition, 24);
      });
    });

    group('addText', () {
      test('check for lines, words and separators', () {
        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasHeight = 1000;
        buildPage.currentPage.pageHeight = size.canvasHeight;
        final String paragraph = """The cutter passed from sunlit brilliance to soot-black shadow with the knife-edge suddenness possible only in space, and the tall, broad-shouldered woman in the black and gold of the Royal Manticoran Navy gazed out the armorplast port at the battle-steel beauty of her command and frowned.""";

        for (final token in splitText(paragraph)) {
          final ElementSize textSize = measureText(token, blockStyle.elementStyle.textStyle, size);
          final TextContent content = TextContent(
            blockStyle: blockStyle,
            elementStyle: blockStyle.elementStyle,
            ascent: textSize.ascent,
            descent: textSize.descent,
            height: textSize.height,
            width: textSize.width,
            text: token,
          );

          for (final el in content.elements) {
            buildLine.addElement(el);
          }
        }
        buildLine.completeParagraph();

        final List<Line> lines = buildPage.lines;
        expect(lines, isNotEmpty);
        expect(lines.first.yPosOnPage, 0);
        expect(lines.first.textIndent, 0);

        final List elements = lines.expand((line) => line.elements).toList();
        expect(elements.whereType<WordElement>().length, greaterThan(0));
        expect(elements.whereType<SpaceSeparator>().length, greaterThan(0));
        expect(elements.whereType<HyphenSeparator>().length, greaterThan(0));

        for (int i = 1; i < lines.length; i++) {
          expect(lines[i].yPosOnPage, greaterThanOrEqualTo(lines[i - 1].yPosOnPage));
          expect(lines[i].textIndent, 0);
        }

        expect(lines.last.alignment, LineAlignment.left);
      });

      test('flows body text around a drop caps element before returning to normal width', () {
        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 180;
        size.canvasHeight = 1000;
        buildPage.currentPage.pageHeight = size.canvasHeight;

        final BlockStyle dropCapsBlockStyle = BlockStyle(elementStyle: ElementStyle());
        final double bodyFontSize = style.fontSize ?? ElementStyle.defaultFontSize;
        dropCapsBlockStyle.elementStyle.textStyle = style.copyWith(fontSize: bodyFontSize * 4);
        dropCapsBlockStyle.elementStyle.isDropCaps = true;

        final TextContent dropCap = buildTextContent(
          text: 'T',
          blockStyle: dropCapsBlockStyle,
          size: size,
          textStyle: dropCapsBlockStyle.elementStyle.textStyle,
          isDropCaps: true,
        );

        buildPage.addElements(dropCap, buildLine);

        const String bodyText = 'his paragraph should wrap across several short lines so we can verify that text flows beside the drop caps before returning to the full line width.';
        for (final token in splitText(bodyText)) {
          final TextContent content = buildTextContent(
            text: token,
            blockStyle: blockStyle,
            size: size,
          );
          buildPage.addElements(content, buildLine);
        }
        buildLine.completeParagraph();

        final List<Line> lines = buildPage.lines;
        expect(lines.length, greaterThanOrEqualTo(3));

        final WordElement firstWord = lines.first.elements.firstWhere((element) => element is WordElement) as WordElement;
        expect(firstWord.word.isDropCaps, isTrue);
        expect(lines.first.dropCapsIndent, 0);

        final List<Line> wrappedAroundDropCap = lines.where((line) => line.dropCapsIndent > 0).toList();
        expect(wrappedAroundDropCap, isNotEmpty);
        expect(wrappedAroundDropCap.first.dropCapsIndent, closeTo(dropCap.width + 3, 0.001));

        final int lastIndentedLine = lines.lastIndexWhere((line) => line.dropCapsIndent > 0);
        expect(lastIndentedLine, isNonNegative);
        expect(lastIndentedLine, lessThan(lines.length - 1));
        expect(lines.sublist(lastIndentedLine + 1).every((line) => line.dropCapsIndent == 0), isTrue);
      });

      test('applies manually extracted first-letter CSS and lays out the paragraph in seven content lines at 800px', () async {
        const String relevantDefaultCss = '''
div {
  display: block;
}

body {
  display: block;
  margin: 8px;
  font-size: 18px;
}

p {
  display: block;
}

b, strong {
  font-weight: bolder;
}

i, cite, em, var, dfn {
  font-style: italic;
}
''';

        // The source EPUB uses a large decorated initial; we add `float: left` and
        // a tuned first-letter size here so the reduced fixture exercises the parser's
        // drop-caps path and reproduces the expected 3-line wrap shape.
        const String relevantBookCss = '''
.element-container-single.element-bodymatter p.first-in-chapter.first-full-width span.first-letter {
  float: left;
  font-size: 180%;
  margin-right: 0.3em;
  margin-top: -0.25em;
  margin-bottom: -0.25em;
}

.element-container-single.element-bodymatter p.first-in-chapter.first-full-width span.first-letter.first-letter-a {
  margin-right: 0.3em;
}
''';

        const String chapterHtml = '''
<html>
  <body>
    <div class="element element-bodymatter element-container-single element-type-chapter element-without-heading">
      <div class="text" id="unnumbered-1-text">
        <p class="first first-in-chapter first-full-width first-with-first-letter-a"><b><i><span class="first-letter first-letter-a first-letter-without-punctuation">A</span>s</i></b> I have often opined, what good does it do a fellow to be a master of the mystic arts if he’s not allowed to do a bally thing with said mastery? And while I’ll admit that knocking the toppers off one’s fellow practitioners at Goodwood might have been a tad childish, it hardly, to my mind, constituted a hanging offence. Alas, the old sticks at the Folly didn’t see eye to eye with me on this, so I decided that perhaps it would be wise to remove myself somewhere out of their censorious gaze until the blissful waters of Lethe bathed their cares away. Or something.</p>
      </div>
    </div>
  </body>
</html>
''';

        final CssParser cssParser = GetIt.instance.get<CssParser>();
        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final PageSize size = GetIt.instance.get<PageSize>();
        final double originalDefaultFontSize = ElementStyle.defaultFontSize;

        ElementStyle.defaultFontSize = 18;
        addTearDown(() {
          ElementStyle.defaultFontSize = originalDefaultFontSize;
        });

        size.canvasWidth = 800;
        size.canvasHeight = 2000;
        size.pixelDensity = 0.5;
        size.leftIndent = 0;
        size.rightIndent = 0;

        cssParser.parseCss(relevantDefaultCss);
        cssParser.parseCss(relevantBookCss);

        expect(
          cssParser.css['.element-container-single.element-bodymatter p.first-in-chapter.first-full-width span.first-letter'],
          containsPair('font-size', '180%'),
        );
        expect(
          cssParser.css['.element-container-single.element-bodymatter p.first-in-chapter.first-full-width span.first-letter.first-letter-a'],
          containsPair('margin-right', '0.3em'),
        );

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        expect(chapter.pages.length, 1);

        final List<Line> lines = chapter.pages.single.lines.where((line) => line.elements.isNotEmpty).toList();
        final List<String> renderedLines = lines.map(lineText).toList();

        expect(lines.length, 7);

        final WordElement firstWord = lines.first.elements.firstWhere((element) => element is WordElement) as WordElement;
        expect(firstWord.word.text, 'A');
        expect(firstWord.word.isDropCaps, isTrue);
        expect(renderedLines.first.startsWith('As I have often opined,'), isTrue);

        expect(lines[1].dropCapsIndent, greaterThan(0));
        expect(lines[2].dropCapsIndent, greaterThan(0));
        expect(lines[3].dropCapsIndent, 0);
        expect(lines[4].dropCapsIndent, 0);
        expect(lines[5].dropCapsIndent, 0);
        expect(lines[6].dropCapsIndent, 0);
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
        final List<double> yPositions = lines.map((line) => line.yPosOnPage).toList();
        for (int i = 1; i < yPositions.length; i++) {
          expect(yPositions[i], greaterThanOrEqualTo(yPositions[i - 1]));
        }
        expect(yPositions.toSet().length, greaterThan(1));
      });
    });

}
