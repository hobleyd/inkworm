import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:inkworm/epub/cache/link_cache.dart';
import 'package:inkworm/epub/cache/text_cache.dart';
import 'package:inkworm/epub/elements/line_element.dart';
import 'package:inkworm/epub/elements/link_element.dart';
import 'package:inkworm/epub/handlers/block_handler.dart';
import 'package:inkworm/epub/handlers/inline_handler.dart';
import 'package:inkworm/epub/handlers/line_break_handler.dart';
import 'package:inkworm/epub/handlers/link_handler.dart';
import 'package:inkworm/epub/handlers/superscript_handler.dart';
import 'package:inkworm/epub/handlers/text_handler.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';
import 'package:inkworm/epub/parser/isolates/worker_slot.dart';
import 'package:inkworm/epub/structure/build_line.dart';
import 'package:inkworm/epub/structure/build_page.dart';
import 'package:inkworm/epub/structure/epub_chapter.dart';
import 'package:inkworm/epub/structure/line.dart';
import 'package:inkworm/epub/styles/block_style.dart';
import 'package:inkworm/models/page_size.dart';

void main() {
  late EpubParser parser;
  late PageSize size;
  late ReceivePort uiPort;

  // A minimal three-item spine ("titlepage", "ch1", "ch2") so spineIndexForFile() can resolve
  // real chapter positions, mirroring how a book's container.xml/OPF pair looks in practice.
  const String containerXml = '''
<?xml version="1.0"?>
<container>
  <rootfiles>
    <rootfile full-path="content.opf"/>
  </rootfiles>
</container>
''';

  const String opfXml = '''
<?xml version="1.0"?>
<package xmlns:dc="http://purl.org/dc/elements/1.1/">
  <manifest>
    <item id="contents" href="contents.html" media-type="application/xhtml+xml"/>
    <item id="titlepage" href="titlepage.html" media-type="application/xhtml+xml"/>
    <item id="ch1" href="ch1.html" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="contents"/>
    <itemref idref="titlepage"/>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>
''';

  Archive buildArchive(Map<String, String> extraFiles) {
    final Archive archive = Archive();
    archive.addFile(ArchiveFile.string('META-INF/container.xml', containerXml));
    archive.addFile(ArchiveFile.string('content.opf', opfXml));
    for (final entry in extraFiles.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    return archive;
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    GetIt.instance.registerSingleton<CssParser>(CssParser());
    GetIt.instance.registerSingleton<PageSize>(PageSize());
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
    GetIt.instance.registerSingleton<SuperscriptHandler>(SuperscriptHandler());

    final BuildPage buildPage = GetIt.instance.get<BuildPage>();
    final BuildLine buildLine = GetIt.instance.get<BuildLine>();
    buildLine.lineListener = buildPage;

    parser = GetIt.instance.get<EpubParser>();

    size = GetIt.instance.get<PageSize>();
    size.canvasWidth = 800;
    size.canvasHeight = 600;
    size.pixelDensity = 1;
    size.leftIndent = 0;
    size.rightIndent = 0;

    uiPort = ReceivePort();
    uiPort.listen((dynamic request) {
      request.process(uiPort.sendPort);
    });
    WorkerSlot.staticUIPort = uiPort.sendPort;
  });

  tearDown(() {
    uiPort.close();
    WorkerSlot.staticUIPort = null;
    GetIt.instance.reset();
  });

  Iterable<LineElement> allLineElements(EpubChapter chapter) =>
      chapter.pages.expand((page) => page.lines).expand((line) => line.elements);

  group('LinkHandler footnote/navigation classification', () {
    test('a link to the table of contents is treated as navigation, not a footnote, even if its text looks like one', () async {
      // "1" alone matches StringFootnotes.isFootnote, but a link into contents.html must still resolve
      // to a navigable chapter link rather than being rendered as a footnote marker.
      const String chapterHtml = '''
<html><body>
<p>See the <a href="contents.html#toc-ch1">1</a> entry.</p>
</body></html>
''';

      parser.bookArchive = buildArchive({'ch2.html': chapterHtml});
      parser.currentChapterIndex = 3; // ch2 is spine position 3.

      final EpubChapter chapter = EpubChapter(chapterNumber: 3);
      await parser.parseChapterFromString(chapter, chapterHtml);

      final List<LinkElement> links = allLineElements(chapter).whereType<LinkElement>().toList();
      expect(links, isNotEmpty, reason: 'a TOC back-reference should render as a navigable LinkElement');
      expect(links.single.chapterIndex, 0, reason: 'contents.html is spine position 0');

      expect(chapter.pages.single.footnotes, isEmpty);
    });

    test('a footnote-shaped link back to an earlier chapter is treated as navigation, not a footnote', () async {
      const String chapterHtml = '''
<html><body>
<p>Earlier discussion<a href="ch1.html#back1">*</a> covered this.</p>
</body></html>
''';

      parser.bookArchive = buildArchive({'ch1.html': '<html><body><div id="back1"><p>irrelevant</p></div></body></html>'});
      parser.currentChapterIndex = 3; // ch2 is spine position 3; ch1 is spine position 2 (earlier).

      final EpubChapter chapter = EpubChapter(chapterNumber: 3);
      await parser.parseChapterFromString(chapter, chapterHtml);

      final List<LinkElement> links = allLineElements(chapter).whereType<LinkElement>().toList();
      expect(links, isNotEmpty, reason: 'a back-reference to an earlier chapter should navigate, not footnote');
      expect(links.single.chapterIndex, 2);

      expect(chapter.pages.single.footnotes, isEmpty);
    });

    test('a footnote-shaped link forward to a later chapter is still treated as a footnote', () async {
      const String chapterHtml = '''
<html><body>
<p>Something worth a note<a id="fwd1ref" href="ch2.html#fwd1">*</a> here.</p>
</body></html>
''';

      parser.bookArchive = buildArchive({'ch2.html': '<html><body><div id="fwd1"><p>The footnote text.</p></div></body></html>'});
      parser.currentChapterIndex = 2; // ch1 is spine position 2; ch2 (the footnote target) is position 3, later.

      final EpubChapter chapter = EpubChapter(chapterNumber: 2);
      await parser.parseChapterFromString(chapter, chapterHtml);

      final List<LinkElement> links = allLineElements(chapter).whereType<LinkElement>().toList();
      expect(links, isEmpty, reason: 'a forward footnote reference must not become a navigable chapter link');

      final List<Line> footnoteLines = chapter.pages.single.footnotes.where((l) => l.elements.isNotEmpty).toList();
      expect(footnoteLines, isNotEmpty);

      // The marker's own id is registered too, so a second <a id="fwd1ref"> elsewhere referencing the
      // same footnote is recognised as already-processed rather than duplicating the footnote content.
      expect(GetIt.instance.get<LinkCache>().contains('fwd1ref'), isTrue);
    });

    test('overrides left alignment to justify, since a link is an inline element not a block one', () async {
      const String css = 'p { text-align: left; }';
      GetIt.instance.get<CssParser>().parseCss(css);

      // The <a> must be the very first element added to the paragraph's first line: BuildLine.setAlignment
      // only takes effect while the current line is still empty, so this is what makes the override observable.
      const String chapterHtml = '''
<html><body>
<p><a href="ch1.html#x">Link</a> then plain paragraph text long enough to wrap across more than a single line within the narrow canvas used for this test, so that the justified first line is distinguishable from the unjustified last one.</p>
</body></html>
''';

      size.canvasWidth = 220;

      parser.bookArchive = buildArchive({'ch1.html': '<html><body><p>x</p></body></html>'});
      parser.currentChapterIndex = 2;

      final EpubChapter chapter = EpubChapter(chapterNumber: 2);
      await parser.parseChapterFromString(chapter, chapterHtml);

      final List<Line> lines = chapter.pages.expand((p) => p.lines).where((l) => l.elements.isNotEmpty).toList();
      expect(lines.length, greaterThan(1));
      // The link (first on the line) forced justify for that first line, which then propagates to every
      // wrapped continuation line - except the paragraph's own last line, which BuildLine.completeParagraph
      // always demotes from justify back to left regardless of what set it.
      expect(lines.first.alignment, LineAlignment.justify);
      expect(lines.last.alignment, LineAlignment.left);
    });
  });

  group('SuperscriptHandler footnote attachment', () {
    test('a footnote link wrapped in <sup> attaches its footnote content to the page', () async {
      // Link text ("note") is deliberately not footnote-shaped (not all-digits/asterisks/"fn123"), and
      // the <a> itself carries no vertical-align attribute, so LinkHandler's own footnote detection does
      // NOT fire here - only SuperscriptHandler's dedicated "child is LinkContent" footnote path does.
      const String chapterHtml = '''
<html><body>
<p>Body text<sup><a href="notes.html#n1">note</a></sup> continues.</p>
</body></html>
''';

      parser.bookArchive = buildArchive({
        'notes.html': '<html><body><div id="n1"><p>The attached footnote text.</p></div></body></html>',
      });
      parser.currentChapterIndex = 2;

      final EpubChapter chapter = EpubChapter(chapterNumber: 2);
      await parser.parseChapterFromString(chapter, chapterHtml);

      final List<Line> footnoteLines = chapter.pages.single.footnotes.where((l) => l.elements.isNotEmpty).toList();
      expect(footnoteLines, isNotEmpty);

      final String footnoteText = footnoteLines
          .expand((l) => l.elements)
          .map((el) {
            final dynamic content = el.element;
            return content?.text ?? '';
          })
          .join();
      expect(footnoteText, contains('attached footnote text'));
    });
  });
}
