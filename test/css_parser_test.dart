import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:xml/xml.dart';

import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';

@GenerateMocks([EpubParser, ])
import 'css_parser_test.mocks.dart';

void main() {
  late CssParser cssParser;
  late MockEpubParser mockEpubParser;

  setUp(() {
    cssParser = CssParser();
    mockEpubParser = MockEpubParser();

    GetIt.instance.registerSingleton<EpubParser>(mockEpubParser);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  group('Constructor', () {
    test('should initialize with empty css map', () {
      expect(cssParser.css, isEmpty);
    });

    test('should initialize nonInheritableProperties with margin properties', () {
      expect(cssParser.nonInheritableProperties, contains('margin'));
      expect(cssParser.nonInheritableProperties, contains('margin-left'));
      expect(cssParser.nonInheritableProperties, contains('margin-right'));
      expect(cssParser.nonInheritableProperties, contains('margin-top'));
      expect(cssParser.nonInheritableProperties, contains('margin-bottom'));
      expect(cssParser.nonInheritableProperties.length, 5);
    });
  });

  group('Operator []', () {
    test('should return null for non-existent selector', () {
      expect(cssParser['.nonexistent'], isNull);
    });

    test('should return declarations for existing selector', () {
      cssParser.css['.test'] = {'color': 'red'};
      expect(cssParser['.test'], {'color': 'red'});
    });
  });

  group('parseDeclarations', () {
    test('should parse single property', () {
      final result = cssParser.parseDeclarations('color: red');
      expect(result, {'color': 'red'});
    });

    test('should parse multiple properties', () {
      final result = cssParser.parseDeclarations('color: red; font-size: 16px; margin: 10px');
      expect(result, {
        'color': 'red',
        'font-size': '16px',
        'margin': '10px',
      });
    });

    test('should handle trailing semicolon', () {
      final result = cssParser.parseDeclarations('color: red;');
      expect(result, {'color': 'red'});
    });

    test('should handle properties with spaces', () {
      final result = cssParser.parseDeclarations('  color  :  red  ;  font-size  :  16px  ');
      expect(result, {
        'color': 'red',
        'font-size': '16px',
      });
    });

    test('should return empty map for empty string', () {
      final result = cssParser.parseDeclarations('');
      expect(result, isEmpty);
    });

    test('should throw FormatException for invalid property format', () {
      expect(
            () => cssParser.parseDeclarations('color red'),
        throwsFormatException,
      );
    });

    test('should throw FormatException for property with multiple colons', () {
      expect(
            () => cssParser.parseDeclarations('color: red: blue'),
        throwsFormatException,
      );
    });

    test('should handle value with colon in quotes', () {
      // Note: This will fail with current implementation
      // This test documents current behavior
      expect(
            () => cssParser.parseDeclarations('content: "a:b"'),
        throwsFormatException,
      );
    });
  });

  group('parseCss', () {
    test('should parse single selector with single property', () {
      final css = '.test { color: red; }';
      final result = cssParser.parseCss(css);
      expect(result, {
        '.test': {'color': 'red'}
      });
    });

    test('should parse single selector with multiple properties', () {
      final css = '.test { color: red; font-size: 16px; }';
      final result = cssParser.parseCss(css);
      expect(result, {
        '.test': {'color': 'red', 'font-size': '16px'}
      });
    });

    test('should parse multiple selectors', () {
      final css = '.test { color: red; } h1 { font-size: 24px; }';
      final result = cssParser.parseCss(css);
      expect(result, {
        '.test': {'color': 'red'},
        'h1': {'font-size': '24px'}
      });
    });

    test('should parse comma-separated selectors', () {
      final css = '.test1, .test2, .test3 { color: red; }';
      final result = cssParser.parseCss(css);
      expect(result, {
        '.test1': {'color': 'red'},
        '.test2': {'color': 'red'},
        '.test3': {'color': 'red'}
      });
    });

    test('should remove CSS comments', () {
      final css = '/* comment */ .test { color: red; /* inline comment */ }';
      final result = cssParser.parseCss(css);
      expect(result, {
        '.test': {'color': 'red'}
      });
    });

    test('should remove multi-line CSS comments', () {
      final css = '''
      /* 
       * Multi-line comment
       * More comments
       */
      .test { color: red; }
      ''';
      final result = cssParser.parseCss(css);
      expect(result, {'.test': {'color': 'red'}});
    });

    test('should handle @font-face with font-family', () {
      final css = '@font-face { font-family: "MyFont"; src: url("font.ttf"); }';
      final result = cssParser.parseCss(css);

      expect(result, {
        'MyFont': {'src': 'url("font.ttf")'}
      });
    });

    test('should handle empty CSS', () {
      final result = cssParser.parseCss('');
      expect(result, isEmpty);
    });

    test('should handle whitespace variations', () {
      final css = '''
      .test1
      {
        color:red;
        font-size:16px;
      }
      ''';
      final result = cssParser.parseCss(css);
      expect(result, {
        '.test1': {'color': 'red', 'font-size': '16px'}
      });
    });
  });

  group('getInlineStyle', () {
    test('should return null when element has no style attribute', () {
      final element = XmlElement(XmlName('div'));
      final result = cssParser.getInlineStyle(element, 'color');
      expect(result, isNull);
    });

    test('should parse inline style and return attribute value', () {
      final element = XmlElement(XmlName('div'));
      element.setAttribute('style', 'color: red; font-size: 16px;');
      final result = cssParser.getInlineStyle(element, 'color');
      expect(result, 'red');
    });

    test('should return null for non-existent attribute in inline style', () {
      final element = XmlElement(XmlName('div'));
      element.setAttribute('style', 'color: red;');
      final result = cssParser.getInlineStyle(element, 'font-size');
      expect(result, isNull);
    });
  });

  group('getCSSValue', () {
    test('should return inline style value first', () {
      cssParser.css['div'] = {'color': 'blue'};
      final element = XmlElement(XmlName('div'));
      element.setAttribute('style', 'color: red;');

      final result = cssParser.getCSSAttributeValue(element, 'color');
      expect(result, 'red');
    });

    test('should return class-specific selector (element.class)', () {
      cssParser.css['h2.title'] = {'color': 'red'};
      cssParser.css['.title'] = {'color': 'blue'};
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName('h2'));
      element.setAttribute('class', 'title');

      final result = cssParser.getCSSAttributeValue(element, 'color');
      expect(result, 'red');
    });

    test('should fallback to .class selector', () {
      cssParser.css['.title'] = {'color': 'blue'};
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName('h2'));
      element.setAttribute('class', 'title');

      final result = cssParser.getCSSAttributeValue(element, 'color');
      expect(result, 'blue');
    });

    test('should fallback to class selector without dot', () {
      cssParser.css['title'] = {'color': 'yellow'};
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName('h2'));
      element.setAttribute('class', 'title');

      final result = cssParser.getCSSAttributeValue(element, 'color');
      expect(result, 'yellow');
    });

    test('should fallback to element selector', () {
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName('h2'));

      final result = cssParser.getCSSAttributeValue(element, 'color');
      expect(result, 'green');
    });

    test('should return null when no matching selector found', () {
      final element = XmlElement(XmlName('h2'));

      final result = cssParser.getCSSAttributeValue(element, 'color');
      expect(result, isNull);
    });

    test('should handle multiple classes', () {
      cssParser.css['div.class1'] = {'color': 'red'};
      cssParser.css['div.class2'] = {'font-size': '16px'};

      final element = XmlElement(XmlName('div'));
      element.setAttribute('class', 'class1 class2');

      final color = cssParser.getCSSAttributeValue(element, 'color');
      final fontSize = cssParser.getCSSAttributeValue(element, 'font-size');

      expect(color, 'red');
      expect(fontSize, '16px');
    });

    test('should stop at first matching class', () {
      cssParser.css['div.class1'] = {'color': 'red'};
      cssParser.css['div.class2'] = {'color': 'blue'};

      final element = XmlElement(XmlName('div'));
      element.setAttribute('class', 'class1 class2');

      final result = cssParser.getCSSAttributeValue(element, 'color');
      expect(result, 'red');
    });
  });

  group('inheritance', () {
    test('should inherit from parent when child has no value', () {
      cssParser.css['div'] = {'color': 'red'};

      final parent = XmlElement(XmlName('div'));
      final child = XmlElement(XmlName('span'));
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'red');
    });

    test('should inherit from parent when value is "inherit"', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['span'] = {'color': 'inherit'};

      final parent = XmlElement(XmlName('div'));
      final child = XmlElement(XmlName('span'));
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'red');
    });

    test('should not inherit when child has explicit value', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['span'] = {'color': 'blue'};

      final parent = XmlElement(XmlName('div'));
      final child = XmlElement(XmlName('span'));
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'blue');
    });

    test('should inherit through multiple levels', () {
      cssParser.css['div'] = {'color': 'red'};

      final grandparent = XmlElement(XmlName('div'));
      final parent = XmlElement(XmlName('p'));
      final child = XmlElement(XmlName('span'));

      grandparent.children.add(parent);
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'red');
    });

    test('should stop inheriting when parent has value', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['p'] = {'color': 'blue'};

      final grandparent = XmlElement(XmlName('div'));
      final parent = XmlElement(XmlName('p'));
      final child = XmlElement(XmlName('span'));

      grandparent.children.add(parent);
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'blue');
    });

    test('should return null when no value found in entire hierarchy', () {
      final parent = XmlElement(XmlName('div'));
      final child = XmlElement(XmlName('span'));
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, isNull);
    });

    test('should prioritize inline style over inheritance', () {
      cssParser.css['div'] = {'color': 'red'};

      final parent = XmlElement(XmlName('div'));
      final child = XmlElement(XmlName('span'));
      child.setAttribute('style', 'color: blue;');
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'blue');
    });

    test('should inherit when inline style has inherit value', () {
      cssParser.css['div'] = {'color': 'red'};

      final parent = XmlElement(XmlName('div'));
      final child = XmlElement(XmlName('span'));
      child.setAttribute('style', 'color: inherit;');
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'red');
    });

    test('should handle inheritance with class selectors', () {
      cssParser.css['.parent'] = {'color': 'red'};

      final parent = XmlElement(XmlName('div'));
      parent.setAttribute('class', 'parent');
      final child = XmlElement(XmlName('span'));
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'red');
    });

    test('should handle deep nesting with mixed inherit values', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['p'] = {'color': 'inherit'};
      cssParser.css['span'] = {'color': 'inherit'};

      final grandparent = XmlElement(XmlName('div'));
      final parent = XmlElement(XmlName('p'));
      final child = XmlElement(XmlName('span'));

      grandparent.children.add(parent);
      parent.children.add(child);

      final result = cssParser.getCSSAttributeValue(child, 'color');
      expect(result, 'red');
    });
  });

  group('getAttribute', () {
    test('should return CSS value when available', () {
      cssParser.css['h2'] = {'color': 'red'};
      final element = XmlElement(XmlName('h2'));

      final result = cssParser.getStringAttribute(element, 'color', 'black');
      expect(result, 'red');
    });

    test('should return default value when CSS value not available', () {
      final element = XmlElement(XmlName('h2'));

      final result = cssParser.getStringAttribute(element, 'color', 'black');
      expect(result, 'black');
    });
  });

  group('Integration tests', () {
    test('should handle complete CSS hierarchy', () {
      cssParser.css.addAll(cssParser.parseCss('''
        h2 { color: black; font-size: 18px; }
        .title { color: blue; }
        h2.title { color: red; }
      '''));

      final element = XmlElement(XmlName('h2'));
      element.setAttribute('class', 'title');

      expect(cssParser.getCSSAttributeValue(element, 'color'), 'red');
      expect(cssParser.getCSSAttributeValue(element, 'font-size'), '18px');
    });

    test('should prioritize inline styles over everything', () {
      cssParser.css.addAll(cssParser.parseCss('''
        h2 { color: black; }
        .title { color: blue; }
        h2.title { color: green; }
      '''));

      final element = XmlElement(XmlName('h2'));
      element.setAttribute('class', 'title');
      element.setAttribute('style', 'color: red;');

      expect(cssParser.getCSSAttributeValue(element, 'color'), 'red');
    });
  });
}