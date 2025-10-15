import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkworm/epub/constants.dart';
import 'package:inkworm/epub/elements/separators/space_separator.dart';
import 'package:inkworm/epub/epub.dart';
import 'package:inkworm/epub/elements/line.dart';
import 'package:inkworm/epub/elements/word.dart';
import 'package:inkworm/epub/elements/epub_page.dart';
import 'package:mockito/annotations.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([Line, Word, SpaceSeparator, Epub])
void main() {
    group('text parsing', () {
    late EpubPage epubPage;
    late TextStyle style;
    late ThemeData themeData;

    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();

      epubPage = EpubPage();
      PageConstants.canvasHeight = 367;
      PageConstants.canvasWidth = 378;

      themeData = ThemeData(
        colorSchemeSeed: Colors.white,
        fontFamily: Platform.isMacOS ? 'San Francisco' : GoogleFonts
            .gentiumBookPlus()
            .fontFamily,
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
                style = Theme
                    .of(context)
                    .textTheme
                    .bodySmall!;
                return Container();
              },
            ),
          ),
        ),
      );
    });

    group('constructor', () {
      test('should initialize with empty lines and overflow lists', () {
        expect(epubPage.lines, isEmpty);
        expect(epubPage.overflow, isEmpty);
      });
    });

    group('addText', () {
      test('check for lines, words and separators', () {
        epubPage.addText(
            TextSpan(
                text: """The cutter passed from sunlit brilliance to soot-black shadow with the knife-edge suddenness possible only in space, and the tall, broad-shouldered woman in the black and gold of the Royal Manticoran Navy gazed out the armorplast port at the battle-steel beauty of her command and frowned.""",
                style: style,),
            []);

        debugPrint('${epubPage.lines}');
        expect(epubPage.lines.length, 5);
        expect(epubPage.lines[0].yPos, 0);
        expect(epubPage.lines[0].textIndent, 18);
        expect(epubPage.lines[1].yPos, 16);
        expect(epubPage.lines[1].textIndent, 0);
        expect(epubPage.lines[2].yPos, 32);
        expect(epubPage.lines[2].textIndent, 0);
        expect(epubPage.lines[3].yPos, 48);
        expect(epubPage.lines[3].textIndent, 0);
        expect(epubPage.lines[4].yPos, 64);
        expect(epubPage.lines[4].textIndent, 0);
        expect(epubPage.lines[4].alignment, LineAlignment.left);
      });

      /*
      test('should move line to overflow when exceeding canvas height', () {
        PageConstants.canvasHeight = 100;

        epubPage.addLine(false);
        epubPage.lines.first.height = 120.0; // Exceeds canvas height

        epubPage.addLine(false);

        expect(epubPage.overflow.length, 1);
        expect(epubPage.overflow.first.yPos, 0);
      });
    });

    group('addLines', () {
      test('should add all provided lines to the page', () {
        final linesToAdd = [
          Line(yPos: 0),
          Line(yPos: 20),
          Line(yPos: 40),
        ];

        epubPage.addLines(linesToAdd);

        expect(epubPage.lines.length, 3);
        expect(epubPage.lines[0].yPos, 0);
        expect(epubPage.lines[1].yPos, 20);
        expect(epubPage.lines[2].yPos, 40);
      });

      test('should append to existing lines', () {
        epubPage.addLine(false);
        final initialCount = epubPage.lines.length;

        final linesToAdd = [Line(yPos: 10), Line(yPos: 20)];
        epubPage.addLines(linesToAdd);

        expect(epubPage.lines.length, initialCount + 2);
      });
       */
    });
  });
}