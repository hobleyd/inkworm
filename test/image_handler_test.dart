import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:xml/xml.dart';

import 'package:inkworm/epub/cache/image_cache.dart';
import 'package:inkworm/epub/cache/text_cache.dart';
import 'package:inkworm/epub/content/image_content.dart';
import 'package:inkworm/epub/handlers/image_handler.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';
import 'package:inkworm/epub/parser/isolates/worker_slot.dart';
import 'package:inkworm/models/page_size.dart';

void main() {
  late ImageHandler imageHandler;
  late EpubParser epubParser;
  late PageSize pageSize;
  late ReceivePort uiPort;

  // A minimal, valid 1x1 red-pixel PNG - decodable by ui.decodeImageFromList so
  // MeasureImageRequest can report real (if trivial) intrinsic dimensions.
  final Uint8List onePixelPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  XmlElement imageElement(String xml) => XmlDocument.parse(xml).rootElement;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    GetIt.instance.registerSingleton<CssParser>(CssParser());
    GetIt.instance.registerSingleton<PageSize>(PageSize());
    GetIt.instance.registerSingleton<EpubParser>(EpubParser());
    GetIt.instance.registerSingleton<ImageCache>(ImageCache());
    GetIt.instance.registerSingleton<TextCache>(TextCache());

    epubParser = GetIt.instance.get<EpubParser>();
    pageSize = GetIt.instance.get<PageSize>();
    pageSize.canvasWidth = 800;
    pageSize.canvasHeight = 600;
    pageSize.pixelDensity = 1;

    final Archive archive = Archive();
    archive.addFile(ArchiveFile.bytes('images/photo.png', onePixelPng));
    epubParser.bookArchive = archive;

    uiPort = ReceivePort();
    uiPort.listen((dynamic request) {
      request.process(uiPort.sendPort);
    });
    WorkerSlot.staticUIPort = uiPort.sendPort;

    imageHandler = ImageHandler();
  });

  tearDown(() {
    uiPort.close();
    WorkerSlot.staticUIPort = null;
    GetIt.instance.get<ImageCache>().clear();
    GetIt.instance.reset();
  });

  group('ImageHandler', () {
    test('uses intrinsic image size when no width/height is specified', () async {
      final element = imageElement('<img src="images/photo.png"/>');

      final result = await imageHandler.processElement(node: element);

      expect(result, hasLength(1));
      final ImageContent content = result.single as ImageContent;
      expect(content.image, 'images/photo.png');
      expect(content.width, 1);
      expect(content.height, 1);
      expect(content.requiredWidth, 1);
      expect(content.requiredHeight, 1);
    });

    test('falls back to xlink:href when src is absent', () async {
      final element = imageElement('<image xlink:href="images/photo.png"/>');

      final result = await imageHandler.processElement(node: element);

      expect(result, hasLength(1));
      expect((result.single as ImageContent).image, 'images/photo.png');
    });

    test('returns no content when neither src nor xlink:href is present', () async {
      final element = imageElement('<img alt="missing"/>');

      final result = await imageHandler.processElement(node: element);

      expect(result, isEmpty);
    });

    test('skips the element entirely when display:none', () async {
      final element = imageElement('<img src="images/photo.png" style="display:none"/>');

      final result = await imageHandler.processElement(node: element);

      expect(result, isEmpty);
    });

    test('scales required height to preserve aspect ratio when width is a percentage', () async {
      pageSize.canvasWidth = 400;
      final element = imageElement('<img src="images/photo.png" style="width:50%"/>');

      final result = await imageHandler.processElement(node: element);

      final ImageContent content = result.single as ImageContent;
      // Source image is 1x1 (square), so height must scale by the same factor as width.
      expect(content.requiredWidth, 200);
      expect(content.requiredHeight, 200);
    });

    test('scales required width to preserve aspect ratio when height is a percentage', () async {
      pageSize.canvasHeight = 300;
      final element = imageElement('<img src="images/photo.png" style="height:50%"/>');

      final result = await imageHandler.processElement(node: element);

      final ImageContent content = result.single as ImageContent;
      expect(content.requiredHeight, 150);
      expect(content.requiredWidth, 150);
    });

    test('uses explicit pixel width and height attributes verbatim', () async {
      final element = imageElement('<img src="images/photo.png" width="200" height="100"/>');

      final result = await imageHandler.processElement(node: element);

      final ImageContent content = result.single as ImageContent;
      expect(content.requiredWidth, 200);
      expect(content.requiredHeight, 100);
    });

    test('an explicit width with no height does not rescale the intrinsic height', () async {
      // Documents current behaviour: only the percentage branches preserve aspect ratio;
      // a bare pixel width with no height leaves requiredHeight at the source image's own height.
      final element = imageElement('<img src="images/photo.png" width="200"/>');

      final result = await imageHandler.processElement(node: element);

      final ImageContent content = result.single as ImageContent;
      expect(content.requiredWidth, 200);
      expect(content.requiredHeight, 1);
    });
  });
}
