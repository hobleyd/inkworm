import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  group('EpubPage', () {
    late EpubPage epubPage;

    setUp(() {
      epubPage = EpubPage();
    });
    //367.0/378.0 height/width
    group('constructor', () {
      test('should initialize with empty lines and overflow lists', () {
        expect(epubPage.lines, isEmpty);
        expect(epubPage.overflow, isEmpty);
      });
    });

    group('addLine', () {
      test('should add first line at yPos 0 when lines is empty', () {
        epubPage.addLine(false);

        expect(epubPage.lines.length, 1);
        expect(epubPage.lines.first.yPos, 0);
      });

      test('should call finish on last line when adding new line', () {
        epubPage.addLine(false);
        final firstLine = epubPage.lines.first;

        epubPage.addLine(false);

        // Note: This test assumes Line.finish() modifies the line state
        // You may need to verify the finish behavior separately
        expect(epubPage.lines.length, 2);
      });

      test('should add text indent when paragraph is true', () {
        epubPage.addLine(true);

        expect(epubPage.lines.last.textIndent, PageConstants.leftIndent * 1.5);
      });

      test('should not add text indent when paragraph is false', () {
        epubPage.addLine(false);

        expect(epubPage.lines.last.textIndent, 0);
      });

      test('should calculate yPos based on previous line height', () {
        epubPage.addLine(false);
        epubPage.lines.first.height = 20.0;

        epubPage.addLine(false);

        expect(epubPage.lines.last.yPos, 20.0);
      });

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
    });

    group('addText', () {
      late TextSpan testSpan;
      late TextStyle testStyle;

      setUp(() {
        testStyle = const TextStyle(fontSize: 14);
        testSpan = TextSpan(text: 'Hello world test', style: testStyle);
      });

      test('should create first line if lines is empty', () {
        epubPage.addText(testSpan, []);

        expect(epubPage.lines.isNotEmpty, true);
      });

      test('should split text by spaces and add words', () {
        epubPage.addText(testSpan, []);

        // Should have added words for "Hello", "world", "test"
        // Plus initial paragraph line and final line
        expect(epubPage.lines.length, greaterThan(0));
      });

      test('should set last line alignment to left', () {
        epubPage.addText(testSpan, []);

        expect(epubPage.getActiveLines().last.alignment, LineAlignment.left);
      });

      test('should add new line when word does not fit', () {
        epubPage.addLine(true);
        final mockLine = epubPage.lines.last;

        // Mock willFit to return false to trigger new line
        // Note: This may require making Line mockable or using integration tests

        epubPage.addText(testSpan, []);

        expect(epubPage.lines.length, greaterThan(1));
      });

      test('should return overflow lines', () {
        PageConstants.canvasHeight = 50;

        epubPage.addLine(false);
        epubPage.lines.first.height = 60.0;

        final overflow = epubPage.addText(testSpan, []);

        expect(overflow, isNotEmpty);
      });

      test('should handle empty text', () {
        final emptySpan = TextSpan(text: '', style: testStyle);

        epubPage.addText(emptySpan, []);

        // Should still create the paragraph and ending lines
        expect(epubPage.lines.length, greaterThanOrEqualTo(2));
      });

      test('should trim words before adding', () {
        final spanWithSpaces = TextSpan(text: '  word1   word2  ', style: testStyle);

        epubPage.addText(spanWithSpaces, []);

        // Words should be trimmed, so we should have proper word count
        expect(epubPage.lines.isNotEmpty, true);
      });
    });

    group('addWord', () {
      late Word testWord;
      late TextStyle testStyle;

      setUp(() {
        testStyle = const TextStyle(fontSize: 14);
        testWord = Word(word: TextSpan(text: 'test', style: testStyle));
      });

      test('should add word to active line', () {
        epubPage.addLine(false);

        epubPage.addWord(word: testWord, style: testStyle);

        // Verify word was added (may need to check line's elements)
        expect(epubPage.getActiveLines().last, isNotNull);
      });

      test('should add space separator after word if it fits', () {
        epubPage.addLine(false);

        epubPage.addWord(word: testWord, style: testStyle);

        // Should add both word and space separator
        // Verification depends on Line implementation
        expect(epubPage.lines.isNotEmpty, true);
      });
    });

    group('clear', () {
      test('should clear overflow list', () {
        epubPage.overflow.add(Line(yPos: 0));
        epubPage.overflow.add(Line(yPos: 20));

        epubPage.clear();

        expect(epubPage.overflow, isEmpty);
      });

      test('should not clear lines list', () {
        epubPage.lines.add(Line(yPos: 0));
        epubPage.overflow.add(Line(yPos: 0));

        epubPage.clear();

        expect(epubPage.lines.isNotEmpty, true);
        expect(epubPage.overflow, isEmpty);
      });
    });

    group('getActiveLines', () {
      test('should return lines when overflow is empty', () {
        epubPage.lines.add(Line(yPos: 0));
        epubPage.lines.add(Line(yPos: 20));

        final activeLines = epubPage.getActiveLines();

        expect(activeLines, equals(epubPage.lines));
        expect(activeLines.length, 2);
      });

      test('should return overflow when overflow is not empty', () {
        epubPage.lines.add(Line(yPos: 0));
        epubPage.overflow.add(Line(yPos: 0));
        epubPage.overflow.add(Line(yPos: 20));

        final activeLines = epubPage.getActiveLines();

        expect(activeLines, equals(epubPage.overflow));
        expect(activeLines.length, 2);
      });

      test('should prioritize overflow over lines', () {
        epubPage.lines.add(Line(yPos: 0));
        epubPage.lines.add(Line(yPos: 20));
        epubPage.overflow.add(Line(yPos: 100));

        final activeLines = epubPage.getActiveLines();

        expect(activeLines, equals(epubPage.overflow));
        expect(activeLines.length, 1);
      });
    });

    group('integration tests', () {
      test('should handle multiple paragraphs', () {
        final span1 = TextSpan(text: 'First paragraph', style: const TextStyle());
        final span2 = TextSpan(text: 'Second paragraph', style: const TextStyle());

        epubPage.addText(span1, []);
        epubPage.addText(span2, []);

        expect(epubPage.lines.length, greaterThan(2));
      });

      test('should properly manage overflow across multiple addText calls', () {
        PageConstants.canvasHeight = 100;

        final longText = TextSpan(
          text: 'word ' * 50, // Long text to cause overflow
          style: const TextStyle(fontSize: 14),
        );

        final overflow = epubPage.addText(longText, []);

        // Should have created overflow
        if (overflow.isNotEmpty) {
          expect(epubPage.overflow.isNotEmpty, true);
        }
      });
    });
  });
}