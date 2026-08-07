import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:inkworm/epub/parser/extensions.dart';

void main() {
  group('trimPreservingNbsp', () {
    test('trims plain leading and trailing whitespace', () {
      expect('  hello  '.trimPreservingNbsp(), 'hello');
    });

    test('preserves a leading/trailing non-breaking space', () {
      expect(' hello '.trimPreservingNbsp(), ' hello ');
    });

    test('trims plain whitespace surrounding a preserved non-breaking space', () {
      expect('   hello   '.trimPreservingNbsp(), ' hello ');
    });

    test('returns empty string unchanged', () {
      expect(''.trimPreservingNbsp(), '');
    });
  });

  group('isFootnote', () {
    test('is false for an empty string', () {
      expect(''.isFootnote, isFalse);
    });

    test('is true for a run of asterisks', () {
      expect('**'.isFootnote, isTrue);
    });

    test('is true for a run of dagger/cross marks', () {
      expect('†'.isFootnote, isTrue);
    });

    test('is true for an "fnN" style indicator embedded in other text', () {
      expect('see fn12 above'.isFootnote, isTrue);
    });

    test('is false for ordinary word text', () {
      expect('chapter'.isFootnote, isFalse);
    });
  });

  group('splitReference', () {
    test('splits a file and fragment on the # separator', () {
      expect('chapter1.html#note3'.splitReference, ('chapter1.html', 'note3'));
    });

    test('returns two empty strings when there is no # separator', () {
      expect('chapter1.html'.splitReference, ('', ''));
    });
  });

  group('isEmptyParagraph', () {
    XmlElement paragraph(String xml) => XmlDocument.parse(xml).rootElement;

    test('a <p> with only whitespace text is empty', () {
      expect(isEmptyParagraph(paragraph('<p>   </p>')), isTrue);
    });

    test('a <p> containing only a non-breaking space is not empty', () {
      expect(isEmptyParagraph(paragraph('<p>&#160;</p>')), isFalse);
    });

    test('a <p> with real text is not empty', () {
      expect(isEmptyParagraph(paragraph('<p>Hello</p>')), isFalse);
    });

    test('a <p> containing a child element is not empty, even with no direct text', () {
      expect(isEmptyParagraph(paragraph('<p><br/></p>')), isFalse);
    });

    test('a non-<p> element is never considered an empty paragraph', () {
      expect(isEmptyParagraph(paragraph('<div>   </div>')), isFalse);
    });
  });
}
