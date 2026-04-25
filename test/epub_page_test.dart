import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkworm/epub/cache/link_cache.dart';
import 'package:inkworm/epub/cache/text_cache.dart';
import 'package:inkworm/epub/content/html_content.dart';
import 'package:inkworm/epub/content/image_content.dart';
import 'package:inkworm/epub/structure/epub_chapter.dart';
import 'package:inkworm/epub/content/link_content.dart';
import 'package:inkworm/epub/elements/image_element.dart';
import 'package:inkworm/epub/elements/separators/non_breaking_space_separator.dart';
import 'package:inkworm/epub/handlers/block_handler.dart';
import 'package:inkworm/epub/handlers/css_handler.dart';
import 'package:inkworm/epub/handlers/image_handler.dart';
import 'package:inkworm/epub/handlers/inline_handler.dart';
import 'package:inkworm/epub/handlers/line_break_handler.dart';
import 'package:inkworm/epub/handlers/link_handler.dart';
import 'package:inkworm/epub/handlers/superscript_handler.dart';
import 'package:inkworm/epub/handlers/table_handler.dart';
import 'package:inkworm/epub/handlers/text_handler.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';
import 'package:inkworm/models/page_size.dart';
import 'package:inkworm/epub/content/text_content.dart';
import 'package:inkworm/epub/elements/separators/hyphen_separator.dart';
import 'package:inkworm/epub/elements/separators/space_separator.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/epub/parser/extensions.dart';
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

    List<String> groupedRenderedLines(List<Line> lines) {
      final Map<double, List<Line>> groupedLines = <double, List<Line>>{};

      for (final line in lines.where((line) => line.elements.isNotEmpty)) {
        groupedLines.putIfAbsent(line.yPosOnPage, () => <Line>[]).add(line);
      }

      final List<MapEntry<double, List<Line>>> orderedGroups = groupedLines.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      return orderedGroups.map((entry) {
        final List<Line> rowLines = entry.value
          ..sort((a, b) => a.leftIndent.compareTo(b.leftIndent));
        return rowLines.map(lineText).join(' | ');
      }).toList();
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
      GetIt.instance.registerSingleton<LinkCache>(LinkCache());
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
      GetIt.instance.registerSingleton<TableHandler>(TableHandler());
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

    group('image sizing', () {
      test('uses required width and height when both are specified', () {
        final ImageContent imageContent = ImageContent(
          blockStyle: blockStyle,
          elementStyle: ElementStyle(),
          image: 'test-image',
          bytes: Uint8List(0),
          width: 120,
          height: 80,
          requiredWidth: 40,
          requiredHeight: 30,
        );

        final ImageElement element = imageContent.elements.first as ImageElement;

        expect(element.width, 40);
        expect(element.height, 30);
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

      test('linearizes table rows and cells into readable text', () async {
        const String chapterHtml = '''
<html><body>
<p>Before table.</p>
<table>
  <tbody>
    <tr><th>Planet</th><th>Population</th></tr>
    <tr><td>Manticore</td><td>3.2B</td></tr>
    <tr><td>Grayson</td><td>1.8B</td></tr>
  </tbody>
</table>
<p>After table.</p>
</body></html>
''';

        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 1000;

        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final EpubChapter chapter = EpubChapter(chapterNumber: 0);

        await parser.parseChapterFromString(chapter, chapterHtml);

        expect(chapter.pages, hasLength(1));

        final List<String> renderedLines = groupedRenderedLines(chapter.pages.single.lines);

        expect(renderedLines, contains('Before table.'));
        expect(renderedLines, contains('Planet | Population'));
        expect(renderedLines, contains('Manticore | 3.2B'));
        expect(renderedLines, contains('Grayson | 1.8B'));
        expect(renderedLines, contains('After table.'));
      });

      test('applies fixed table-layout percentage column widths for recipe tables', () async {
        const String tableCss = '''
.recipe-table {
  table-layout: fixed;
  margin-left: 10%;
  margin-right: 10%;
  overflow: hidden;
  width: 80%;
  white-space: wrap;
  font-size: smaller;
  background-color: #dbffe5;
}
.col-ingredients {
  width: 30%;
  text-align: left;
  font-size: smaller;
}
.col-measure {
  width: 15%;
  text-align: left;
  font-size: smaller;
}
''';

        const String chapterHtml = '''
<html><body>
  <table class="recipe-table">
    <thead>
      <tr>
        <th class="col-ingredients">Ingredients</th>
        <th class="col-measure">I</th>
        <th class="col-measure">M</th>
        <th class="col-ingredients">Ingredients</th>
        <th class="col-measure">I</th>
        <th class="col-measure">M</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td class="col-ingredients">Large flat mushrooms</td>
        <td class="col-measure">5</td>
        <td></td>
        <td class="col-ingredients">Basil, chopped</td>
        <td class="col-measure">1tbs</td>
        <td></td>
      </tr>
      <tr>
        <td class="col-ingredients">Mozzarella strips</td>
        <td class="col-measure">6oz</td>
        <td class="col-measure">175g</td>
        <td class="col-ingredients">Egg, beaten</td>
        <td class="col-measure">1</td>
        <td></td>
      </tr>
      <tr>
        <td class="col-ingredients">Garlic</td>
        <td class="col-measure">2 cloves</td>
        <td></td>
        <td class="col-ingredients">Breadcrumbs</td>
        <td class="col-measure">1 oz</td>
        <td class="col-measure">25g</td>
      </tr>
      <tr>
        <td class="col-ingredients">Walnuts, chopped finely</td>
        <td class="col-measure">2 oz</td>
        <td class="col-measure">50g</td>
        <td class="col-ingredients">Olive Oil</td>
        <td class="col-measure">2 tbs</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</body></html>
''';

        final CssParser cssParser = GetIt.instance.get<CssParser>();
        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 1400;
        size.leftIndent = 0;
        size.rightIndent = 0;

        cssParser.parseCss(tableCss);

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        expect(chapter.pages, hasLength(1));

        final List<String> renderedLines = groupedRenderedLines(chapter.pages.single.lines);
        expect(renderedLines, contains('Ingredients | I | M | Ingredients | I | M'));
        expect(renderedLines.join(' '), contains('Large flat'));
        expect(renderedLines.join(' '), contains('mushrooms'));
        expect(renderedLines.join(' '), contains('Basil, chopped'));
        expect(renderedLines.join(' '), contains('1tbs'));
        expect(renderedLines.join(' '), contains('Mozzarella strips'));
        expect(renderedLines.join(' '), contains('175g'));
        expect(renderedLines.join(' '), contains('Egg, beaten'));
        expect(renderedLines.join(' '), contains('Garlic'));
        expect(renderedLines.join(' '), contains('2 cloves'));
        expect(renderedLines.join(' '), contains('Breadcrumbs'));
        expect(renderedLines.join(' '), contains('25g'));
        expect(renderedLines.join(' '), contains('Walnuts, chopped'));
        expect(renderedLines.join(' '), contains('Olive Oil'));
        expect(renderedLines.join(' '), contains('2 tbs'));
        expect(renderedLines.any((line) => line.contains('Large flat mushrooms') && line.contains('Mozzarella strips')), isFalse);
      });

      test('wraps long text within a table cell instead of overflowing into the next column', () async {
        const String tableCss = '''
.recipe-table {
  table-layout: fixed;
  width: 80%;
}
.col-ingredients {
  width: 30%;
  text-align: left;
}
.col-measure {
  width: 15%;
  text-align: left;
}
''';

        const String chapterHtml = '''
<html><body>
  <table class="recipe-table">
    <tbody>
      <tr>
        <td class="col-ingredients">Walnuts chopped very finely until almost powdery</td>
        <td class="col-measure">2 oz</td>
        <td class="col-measure">50g</td>
        <td class="col-ingredients">Olive Oil</td>
        <td class="col-measure">2 tbs</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</body></html>
''';

        final CssParser cssParser = GetIt.instance.get<CssParser>();
        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 220;
        size.canvasHeight = 1000;
        size.leftIndent = 0;
        size.rightIndent = 0;

        cssParser.parseCss(tableCss);

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        expect(chapter.pages, hasLength(1));

        final List<Line> lines = chapter.pages.single.lines.where((line) => line.elements.isNotEmpty).toList();
        expect(lines.length, greaterThan(1));

        final List<Line> firstColumnLines = lines.where((line) => line.leftIndent == 0).toList();
        expect(firstColumnLines.length, greaterThan(1));

        final List<String> groupedLines = groupedRenderedLines(lines);
        expect(groupedLines.join(' '), contains('Walnuts'));
        expect(groupedLines.join(' '), contains('chopped'));
        expect(groupedLines.join(' '), contains('very finely'));
        expect(groupedLines.join(' '), contains('almost powdery'));
        expect(groupedLines.join(' '), contains('2'));
        expect(groupedLines.join(' '), contains('oz'));
        expect(groupedLines.any((line) => line.contains('Walnuts') && line.contains('2')), isTrue);
        expect(groupedLines.any((line) => line.contains('very finely') && line.contains('2 oz')), isFalse);
      });

      test('wrapped table rows reserve enough height before the next row starts', () async {
        const String tableCss = '''
.recipe-table {
  table-layout: fixed;
  width: 80%;
}
.col-ingredients {
  width: 30%;
  text-align: left;
}
.col-measure {
  width: 15%;
  text-align: left;
}
''';

        const String chapterHtml = '''
<html><body>
  <table class="recipe-table">
    <tbody>
      <tr>
        <td class="col-ingredients">Walnuts chopped very finely until almost powdery</td>
        <td class="col-measure">2 oz</td>
        <td class="col-measure">50g</td>
        <td class="col-ingredients">Olive Oil</td>
        <td class="col-measure">2 tbs</td>
        <td></td>
      </tr>
      <tr>
        <td class="col-ingredients">Second row</td>
        <td class="col-measure">1</td>
        <td></td>
        <td class="col-ingredients">Still below</td>
        <td class="col-measure">2</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</body></html>
''';

        final CssParser cssParser = GetIt.instance.get<CssParser>();
        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 220;
        size.canvasHeight = 1000;
        size.leftIndent = 0;
        size.rightIndent = 0;

        cssParser.parseCss(tableCss);

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        final List<String> groupedLines = groupedRenderedLines(chapter.pages.single.lines);
        final int wrappedRowLastIndex = groupedLines.lastIndexWhere((line) => line.contains('powdery') || line.contains('almost'));
        final int secondRowIndex = groupedLines.indexWhere((line) => line.contains('Second') || line.contains('Still below'));

        expect(wrappedRowLastIndex, isNonNegative);
        expect(secondRowIndex, greaterThan(wrappedRowLastIndex));
      });

      test('applies zebra row background colors to table cells', () async {
        const String tableCss = '''
.recipe-table tbody tr:nth-child(odd) td {
  background-color: #f4fff7;
}
.recipe-table tbody tr:nth-child(even) td {
  background-color: #dbffe5;
}
.recipe-table {
  table-layout: fixed;
  width: 80%;
}
.col-ingredients {
  width: 30%;
}
.col-measure {
  width: 15%;
}
''';

        const String chapterHtml = '''
<html><body>
  <table class="recipe-table">
    <tbody>
      <tr>
        <td class="col-ingredients">Row one</td>
        <td class="col-measure">1</td>
        <td></td>
        <td class="col-ingredients">A</td>
        <td class="col-measure">2</td>
        <td></td>
      </tr>
      <tr>
        <td class="col-ingredients">Row two</td>
        <td class="col-measure">3</td>
        <td></td>
        <td class="col-ingredients">B</td>
        <td class="col-measure">4</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</body></html>
''';

        final CssParser cssParser = GetIt.instance.get<CssParser>();
        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 1000;
        size.leftIndent = 0;
        size.rightIndent = 0;

        cssParser.parseCss(tableCss);

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        final page = chapter.pages.single;
        expect(page.backgrounds, isNotEmpty);
        expect(page.backgrounds.where((bg) => bg.color == const Color(0xFFF4FFF7)).length, 1);
        expect(page.backgrounds.where((bg) => bg.color == const Color(0xFFDBFFE5)).length, 1);
      });

      test('applies table background color when rows do not override it', () async {
        const String tableCss = '''
.recipe-table {
  table-layout: fixed;
  width: 80%;
  background-color: #dbffe5;
}
.col-ingredients {
  width: 30%;
}
.col-measure {
  width: 15%;
}
''';

        const String chapterHtml = '''
<html><body>
  <table class="recipe-table">
    <tbody>
      <tr>
        <td class="col-ingredients">Row one</td>
        <td class="col-measure">1</td>
        <td></td>
        <td class="col-ingredients">A</td>
        <td class="col-measure">2</td>
        <td></td>
      </tr>
      <tr>
        <td class="col-ingredients">Row two</td>
        <td class="col-measure">3</td>
        <td></td>
        <td class="col-ingredients">B</td>
        <td class="col-measure">4</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</body></html>
''';

        final CssParser cssParser = GetIt.instance.get<CssParser>();
        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 1000;
        size.leftIndent = 0;
        size.rightIndent = 0;

        cssParser.parseCss(tableCss);

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        final page = chapter.pages.single;
        final backgrounds = page.backgrounds.where((bg) => bg.color == const Color(0xFFDBFFE5)).toList();
        expect(backgrounds.length, 2);
        expect(backgrounds.every((bg) => bg.rect.width == 640), isTrue);
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

    group('footnotes', () {
      test('builds a single footnote from an asterisk link without an anchor id', () async {
        const String chapterHtml = '''
<html><body>
<p class="calibre19">When does it start?</p>
<a class="calibre11"></a><a id="filepos1893" class="calibre11"></a><p class="calibre19">There are very few starts. Oh, some things <span class="italic">seem</span> to be beginnings. The curtain goes up, the first pawn moves, the first shot is fired<a href="Lords_and_Ladies_split_012.html#filepos689280" class="calibre12"><span class="calibre20"><span class="calibre13"><span class="calibre14" style="text-decoration:underline">*</span></span></span></a>—but <span class="italic">that’s</span> not the start. The play, the game, the war is just a little window on a ribbon of events that may extend back thousands of years. The point is, there’s always something <span class="italic">before.</span> It’s <span class="italic">always</span> a case of Now Read On.</p>
</body></html>
''';

        const String footnoteHtml = '''
<html><body>
<div id="filepos689280" class="calibre1"><a class="calibre11"></a><p class="calibre31"><a href="Lords_and_Ladies_split_003.html#filepos1893" class="calibre12"><span class="calibre20"><span class="calibre13"><span class="calibre14" style="text-decoration:underline">*</span></span></span></a><span class="calibre20">Probably at the first pawn.</span></p>
<div class="calibre1"></div>
<div class="mbppagebreak" id="calibre_pb_12"></div>
</div>
</body></html>
''';

        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 600;

        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final Archive archive = Archive();
        archive.addFile(ArchiveFile.string('Lords_and_Ladies_split_003.html', chapterHtml));
        archive.addFile(ArchiveFile.string('Lords_and_Ladies_split_012.html', footnoteHtml));
        parser.bookArchive = archive;

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        expect(chapter.pages.length, 1);
        final List<Line> renderedFootnotes = chapter.pages.single.footnotes.where((line) => line.elements.isNotEmpty).toList();
        expect(renderedFootnotes, hasLength(1));
        expect(lineText(renderedFootnotes.single), contains('Probably at the first pawn.'));
      });

      test('builds nested footnotes when a footnote links to another footnote', () async {
        const String chapterHtml = '''
<html><body>
<a class="calibre11"></a><a id="filepos87864" class="calibre11"></a><p class="calibre19">It was very hard, being a reader in Invisible Writings.<a href="Lords_and_Ladies_split_054.html#filepos705413" class="calibre12"><span class="calibre20"><span class="calibre13"><span class="calibre14" style="text-decoration:underline">*</span></span></span></a></p>
</body></html>
''';

        const String firstFootnoteHtml = '''
<html><body>
<div id="filepos705413" class="calibre1"><a class="calibre11"></a><a id="filepos705418" class="calibre11"></a><p class="calibre31"><a href="Lords_and_Ladies_split_003.html#filepos87864" class="calibre12"><span class="calibre20"><span class="calibre13"><span class="calibre14" style="text-decoration:underline">*</span></span></span></a><span class="calibre20">The study of invisible writings was a new discipline made available by the discovery of the bi-directional nature of Library-Space. The thaumic mathematics are complex, but boil down to the fact that all books, everywhere, affect all other books. This is obvious: books inspire other books written in the future, and cite books written in the past. But the General Theory</span><a href="Lords_and_Ladies_split_055.html#filepos706258" class="calibre12"><span class="calibre20"><span class="calibre13"><span class="calibre14" style="text-decoration:underline">**</span></span></span></a><span class="calibre20"> of L-Space suggests that, in that case, the contents of books </span><span class="calibre20"><span class="italic">as yet unwritten</span></span><span class="calibre20"> can be deduced from books now in existence.</span></p>
</div>
</body></html>
''';

        const String secondFootnoteHtml = '''
<html><body>
<div id="filepos706258" class="calibre1"><a class="calibre11"></a><p class="calibre31"><a href="Lords_and_Ladies_split_054.html#filepos705418" class="calibre12"><span class="calibre20"><span class="calibre13"><span class="calibre14" style="text-decoration:underline">**</span></span></span></a><span class="calibre20">There&apos;s a Special Theory as well, but no one bothers with it much because it&apos;s self-evidently a load of marsh gas.</span></p>
<div class="calibre1"></div>
</div>
</body></html>
''';

        final PageSize size = GetIt.instance.get<PageSize>();
        size.canvasWidth = 800;
        size.canvasHeight = 1000;

        final EpubParser parser = GetIt.instance.get<EpubParser>();
        final Archive archive = Archive();
        archive.addFile(ArchiveFile.string('Lords_and_Ladies_split_003.html', chapterHtml));
        archive.addFile(ArchiveFile.string('Lords_and_Ladies_split_054.html', firstFootnoteHtml));
        archive.addFile(ArchiveFile.string('Lords_and_Ladies_split_055.html', secondFootnoteHtml));
        parser.bookArchive = archive;

        final firstFootnote = parser.getFootnote('Lords_and_Ladies_split_054.html', 'filepos705413');
        final List<HtmlContent>? firstFootnoteElements = await firstFootnote?.handler?.processElement(node: firstFootnote);
        final LinkContent? nestedFootnoteLink = firstFootnoteElements
            ?.whereType<LinkContent>()
            .where((link) => link.href == 'Lords_and_Ladies_split_055.html#filepos706258')
            .firstOrNull;
        final secondFootnote = parser.getFootnote('Lords_and_Ladies_split_055.html', 'filepos706258');

        expect(nestedFootnoteLink, isNotNull);
        expect(secondFootnote, isNotNull);
        expect(nestedFootnoteLink!.footnotes, isNotEmpty);

        final EpubChapter chapter = EpubChapter(chapterNumber: 0);
        await parser.parseChapterFromString(chapter, chapterHtml);

        expect(chapter.pages.length, 1);

        final List<Line> renderedFootnotes = chapter.pages.single.footnotes.where((line) => line.elements.isNotEmpty).toList();
        final List<String> renderedFootnoteText = renderedFootnotes.map(lineText).toList();
        final List<String> footnoteEntries = renderedFootnoteText.where((text) => text.trimLeft().startsWith('*')).toList();

        expect(footnoteEntries, hasLength(2));
        expect(renderedFootnoteText.join(' '), contains('The study of invisible writings'));
        expect(renderedFootnoteText.join(' '), contains("There's a Special Theory as well"));
      });
    });

}
