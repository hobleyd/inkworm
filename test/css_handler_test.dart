import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xml/xml.dart';

import 'package:inkworm/epub/handlers/css_handler.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';

@GenerateMocks([EpubParser])
import 'css_handler_test.mocks.dart';

void main() {
  late CssHandler cssHandler;
  late CssParser cssParser;
  late MockEpubParser mockEpubParser;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    mockEpubParser = MockEpubParser();

    GetIt.instance.registerSingleton<CssParser>(CssParser());
    GetIt.instance.registerSingleton<EpubParser>(mockEpubParser);

    cssParser = GetIt.instance.get<CssParser>();
    cssHandler = CssHandler();
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  XmlElement linkElement(String xml) => XmlDocument.parse(xml).rootElement;

  group('CssHandler', () {
    test('ignores a stylesheet link whose type is not CSS, instead of crashing on a missing archive entry', () async {
      // Older Adobe Digital Editions epubs (e.g. "The Dog Stars") ship a page-template link
      // alongside the real stylesheet; the referenced file isn't part of the archive at all.
      final element = linkElement(
        '<link rel="stylesheet" type="application/vnd.adobe-page-template+xml" href="page-template.xpgt"/>',
      );

      // bookArchive is intentionally left unstubbed: if the handler wrongly tries to load this
      // link as CSS, accessing it will throw and fail the test.
      final result = await cssHandler.processElement(node: element);

      expect(result, isEmpty);
      expect(cssParser.css, isEmpty);
    });

    test('parses a stylesheet link with type="text/css"', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('style.css', 'p { color: red; }'));
      when(mockEpubParser.bookArchive).thenReturn(archive);

      final element = linkElement('<link rel="stylesheet" type="text/css" href="style.css"/>');

      final result = await cssHandler.processElement(node: element);

      expect(result, isEmpty);
      expect(cssParser['p'], {'color': 'red'});
    });

    test('parses a stylesheet link with no type attribute', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('style.css', 'p { color: blue; }'));
      when(mockEpubParser.bookArchive).thenReturn(archive);

      final element = linkElement('<link rel="stylesheet" href="style.css"/>');

      final result = await cssHandler.processElement(node: element);

      expect(result, isEmpty);
      expect(cssParser['p'], {'color': 'blue'});
    });

    test('ignores non-stylesheet links', () async {
      final element = linkElement('<link rel="icon" href="favicon.ico"/>');

      final result = await cssHandler.processElement(node: element);

      expect(result, isEmpty);
      expect(cssParser.css, isEmpty);
    });
  });
}
