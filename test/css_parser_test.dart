import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/models/page_size.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xml/xml.dart';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:inkworm/epub/cache/text_cache.dart';
import 'package:inkworm/epub/parser/css_parser.dart';
import 'package:inkworm/epub/parser/epub_parser.dart';
import 'package:inkworm/epub/parser/font_management.dart';
import 'package:inkworm/epub/parser/isolates/worker_slot.dart';
import 'package:inkworm/epub/styles/block_style.dart';
import 'package:inkworm/epub/styles/element_style.dart';
import 'package:inkworm/epub/styles/table_cell_style.dart';
import 'package:inkworm/epub/styles/table_row_style.dart';
import 'package:inkworm/epub/styles/table_style.dart';

@GenerateMocks([EpubParser, FontManagement])
import 'css_parser_test.mocks.dart';

void main() {
  late CssParser cssParser;
  late MockEpubParser mockEpubParser;
  late MockFontManagement mockFontManagement;
  late ReceivePort uiPort;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    mockEpubParser = MockEpubParser();
    mockFontManagement = MockFontManagement();
    when(mockEpubParser.getBytes(any)).thenReturn(Uint8List(0));

    GetIt.instance.registerSingleton<CssParser>(CssParser());
    GetIt.instance.registerSingleton<PageSize>(PageSize());
    GetIt.instance.registerSingleton<EpubParser>(mockEpubParser);
    GetIt.instance.registerSingleton<FontManagement>(mockFontManagement);
    GetIt.instance.registerSingleton<TextCache>(TextCache());

    cssParser = GetIt.instance.get<CssParser>();
    PageSize size = GetIt.instance.get<PageSize>();

    size.canvasHeight = 800;
    size.canvasWidth = 600;
    size.leftIndent = 12;
    size.rightIndent = 12;
    size.pixelDensity = 1;

    uiPort = ReceivePort();
    uiPort.listen((dynamic request) {
      request.process(uiPort.sendPort);
    });
    WorkerSlot.staticUIPort = uiPort.sendPort;
  });

  tearDown(() {
    uiPort.close();
    GetIt.instance.reset();
  });

  group('Constructor', () {
    test('should initialize with empty css map', () {
      expect(cssParser.css, {});
    });

    test('should initialize nonInheritableProperties with margin properties', () {
      expect(cssParser.nonInheritableProperties, contains('margin'));
      expect(cssParser.nonInheritableProperties, contains('margin-left'));
      expect(cssParser.nonInheritableProperties, contains('margin-right'));
      expect(cssParser.nonInheritableProperties, contains('margin-top'));
      expect(cssParser.nonInheritableProperties, contains('margin-bottom'));
      expect(cssParser.nonInheritableProperties, contains('height'));
      expect(cssParser.nonInheritableProperties.length, 6);
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

    test('should return empty declarations for an @supports block instead of trying to parse it', () {
      final result = cssParser.parseDeclarations('@supports (display: grid) { display: grid; }');
      expect(result, isEmpty);
    });
  });

  group('parseCss', () {
    test('should parse single selector with single property', () {
      final css = '.test { color: red; }';
      cssParser.parseCss(css);
      expect(cssParser.css, {
        '.test': {'color': 'red'}
      });
    });

    test('should parse single selector with multiple properties', () {
      final css = '.test { color: red; font-size: 16px; }';
      cssParser.parseCss(css);
      expect(cssParser.css, {
        '.test': {'color': 'red', 'font-size': '16px'}
      });
    });

    test('should parse multiple selectors', () {
      final css = '.test { color: red; } h1 { font-size: 24px; }';
      cssParser.parseCss(css);
      expect(cssParser.css, {
        '.test': {'color': 'red'},
        'h1': {'font-size': '24px'}
      });
    });

    test('should parse comma-separated selectors', () {
      final css = '.test1, .test2, .test3 { color: red; }';
      cssParser.parseCss(css);
      expect(cssParser.css, {
        '.test1': {'color': 'red'},
        '.test2': {'color': 'red'},
        '.test3': {'color': 'red'}
      });
    });

    test('should remove CSS comments', () {
      final css = '/* comment */ .test { color: red; /* inline comment */ }';
      cssParser.parseCss(css);
      expect(cssParser.css, {
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
      cssParser.parseCss(css);
      expect(cssParser.css, {'.test': {'color': 'red'}});
    });

    test('should handle @font-face with font-family', () {
      final css = '@font-face { font-family: "MyFont"; src: url("font.ttf"); }';
      cssParser.parseCss(css);

      expect(cssParser.css, {
        'MyFont': {'src': 'url("font.ttf")'}
      });
    });

    test('should handle empty CSS', () {
      cssParser.parseCss('');
      expect(cssParser.css, isEmpty);
    });

    test('should handle whitespace variations', () {
      final css = '''
      .test1
      {
        color:red;
        font-size:16px;
      }
      ''';
      cssParser.parseCss(css);
      expect(cssParser.css, {
        '.test1': {'color': 'red', 'font-size': '16px'}
      });
    });
  });

  group('getInlineStyle', () {
    test('should return null when element has no style attribute', () {
      final element = XmlElement(XmlName.parts('div'));
      cssParser.getInlineStyle(element);

      expect(cssParser.css['color'], isNull);
    });

    test('should parse inline style and return attribute value', () {
      final element = XmlElement(XmlName.parts('div'));
      element.setAttribute('style', 'color: red; font-size: 16px;');
      var result = cssParser.getInlineStyle(element);
      expect(result?['color'], 'red');
    });

    test('should return null for non-existent attribute in inline style', () {
      final element = XmlElement(XmlName.parts('div'));
      element.setAttribute('style', 'color: red;');
      cssParser.getInlineStyle(element);
      expect(cssParser.css['font-size'], isNull);
    });
  });

  group('getCSSValue', () {
    test('should return inline style value first', () {
      cssParser.css['div'] = {'color': 'blue'};
      final element = XmlElement(XmlName.parts('div'));
      element.setAttribute('style', 'color: red;');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      var result = cssParser.getStringAttribute(element, style, 'color');
      expect(result, 'red');
    });

    test('should return class-specific selector (element.class)', () {
      cssParser.css['h2.title'] = {'color': 'red'};
      cssParser.css['.title'] = {'color': 'blue'};
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName.parts('h2'));
      element.setAttribute('class', 'title');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      var result = cssParser.getStringAttribute(element, style, 'color');
      expect(result, 'red');
    });

    test('should fallback to .class selector', () {
      cssParser.css['.title'] = {'color': 'blue'};
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName.parts('h2'));
      element.setAttribute('class', 'title');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      var result = cssParser.getStringAttribute(element, style, 'color');
      expect(result, 'blue');
    });

    test('should fallback to class selector without dot', () {
      cssParser.css['title'] = {'color': 'yellow'};
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName.parts('h2'));
      element.setAttribute('class', 'title');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      var result = cssParser.getStringAttribute(element, style, 'color');
      expect(result, 'yellow');
    });

    test('should fallback to element selector', () {
      cssParser.css['h2'] = {'color': 'green'};

      final element = XmlElement(XmlName.parts('h2'));

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      var result = cssParser.getStringAttribute(element, style, 'color');
      expect(result, 'green');
    });

    test('should return null when no matching selector found', () {
      final element = XmlElement(XmlName.parts('h2'));

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      var result = cssParser.getStringAttribute(element, style, 'color');
      expect(result, isNull);
    });

    test('should handle multiple classes', () {
      cssParser.css['div.class1'] = {'color': 'red'};
      cssParser.css['div.class2'] = {'font-size': '16px'};

      final element = XmlElement(XmlName.parts('div'));
      element.setAttribute('class', 'class1 class2');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final color = cssParser.getStringAttribute(element, style, 'color');
      final fontSize = cssParser.getCSSAttributeValue(element, style, 'font-size');

      expect(color, 'red');
      expect(fontSize, '16px');
    });

    test('should stop at first matching class', () {
      cssParser.css['div.class1'] = {'color': 'red'};
      cssParser.css['div.class2'] = {'color': 'blue'};

      final element = XmlElement(XmlName.parts('div'));
      element.setAttribute('class', 'class1 class2');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final color = cssParser.getStringAttribute(element, style, 'color');
      expect(color, 'red');
    });
  });

  group('inheritance', () {
    test('should inherit from parent when child has no value', () {
      cssParser.css['div'] = {'color': 'red'};

      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('span'));
      parent.children.add(child);

      ElementStyle parentStyle = ElementStyle();
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child,);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'red');
    });

    test('should inherit from parent when value is "inherit"', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['span'] = {'color': 'inherit'};

      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('span'));
      parent.children.add(child);

      ElementStyle parentStyle = ElementStyle();
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'red');
    });

    test('should not inherit when child has explicit value', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['span'] = {'color': 'blue'};

      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('span'));
      parent.children.add(child);

      ElementStyle parentStyle = ElementStyle();
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'blue');
    });

    test('should inherit through multiple levels', () {
      cssParser.css['div'] = {'color': 'red'};

      final grandparent = XmlElement(XmlName.parts('div'));
      final parent = XmlElement(XmlName.parts('p'));
      final child = XmlElement(XmlName.parts('span'));

      grandparent.children.add(parent);
      parent.children.add(child);

      ElementStyle grandParentStyle = ElementStyle();
      grandParentStyle.parseElement(element: grandparent);

      ElementStyle parentStyle = ElementStyle(parentStyle: grandParentStyle);
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'red');
    });

    test('should stop inheriting when parent has value', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['p'] = {'color': 'blue'};

      final grandparent = XmlElement(XmlName.parts('div'));
      final parent = XmlElement(XmlName.parts('p'));
      final child = XmlElement(XmlName.parts('span'));

      grandparent.children.add(parent);
      parent.children.add(child);

      ElementStyle grandParentStyle = ElementStyle();
      grandParentStyle.parseElement(element: grandparent);

      ElementStyle parentStyle = ElementStyle(parentStyle: grandParentStyle);
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'blue');
    });

    test('should return null when no value found in entire hierarchy', () {
      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('span'));
      parent.children.add(child);

      ElementStyle parentStyle = ElementStyle();
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, isNull);
    });

    test('should prioritize inline style over inheritance', () {
      cssParser.css['div'] = {'color': 'red'};

      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('span'));
      child.setAttribute('style', 'color: blue;');
      parent.children.add(child);

      ElementStyle parentStyle = ElementStyle();
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'blue');
    });

    test('should inherit when inline style has inherit value', () {
      cssParser.css['div'] = {'color': 'red'};

      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('span'));
      child.setAttribute('style', 'color: inherit;');
      parent.children.add(child);

      ElementStyle parentStyle = ElementStyle();
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'red');
    });

    test('should handle inheritance with class selectors', () {
      cssParser.css['.parent'] = {'color': 'red'};

      final parent = XmlElement(XmlName.parts('div'));
      parent.setAttribute('class', 'parent');
      final child = XmlElement(XmlName.parts('span'));
      parent.children.add(child);

      ElementStyle parentStyle = ElementStyle();
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'red');
    });

    test('should handle deep nesting with mixed inherit values', () {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['p'] = {'color': 'inherit'};
      cssParser.css['span'] = {'color': 'inherit'};

      final grandparent = XmlElement(XmlName.parts('div'));
      final parent = XmlElement(XmlName.parts('p'));
      final child = XmlElement(XmlName.parts('span'));

      grandparent.children.add(parent);
      parent.children.add(child);

      ElementStyle grandParentStyle = ElementStyle();
      grandParentStyle.parseElement(element: grandparent);

      ElementStyle parentStyle = ElementStyle(parentStyle: grandParentStyle);
      parentStyle.parseElement(element: parent);

      ElementStyle style = ElementStyle(parentStyle: parentStyle);
      style.parseElement(element: child);
      final color = cssParser.getStringAttribute(child, style, 'color');
      expect(color, 'red');
    });
  });

  group('getAttribute', () {
    test('should return CSS value when available', () {
      cssParser.css['h2'] = {'color': 'red'};
      final element = XmlElement(XmlName.parts('h2'));

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final color = cssParser.getStringAttribute(element, style, 'color');
      expect(color, 'red');
    });

  });

  group('ElementStyle.getElementStyle', () {
    test('should create and parse an element style with its parent style', () async {
      cssParser.css['div'] = {'color': 'red'};
      cssParser.css['span'] = {'font-size': '18px'};

      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('span'));
      parent.children.add(child);

      final ElementStyle parentStyle = await ElementStyle.getElementStyle(parent, null);
      final ElementStyle style = await ElementStyle.getElementStyle(child, parentStyle);

      expect(cssParser.getStringAttribute(child, style, 'color'), 'red');
      expect(cssParser.getStringAttribute(child, style, 'font-size'), '18px');
    });
  });

  group('BlockStyle.getBlockStyle', () {
    test('should create and parse a block style with its parent style', () async {
      cssParser.css['div'] = {'text-align': 'center'};
      cssParser.css['p'] = {'display': 'none'};

      final parent = XmlElement(XmlName.parts('div'));
      final child = XmlElement(XmlName.parts('p'));
      parent.children.add(child);

      final ElementStyle parentElementStyle = await ElementStyle.getElementStyle(parent, null);
      final BlockStyle parentBlockStyle = await BlockStyle.getBlockStyle(
        parent,
        elementStyle: parentElementStyle,
      );

      final ElementStyle childElementStyle = await ElementStyle.getElementStyle(child, parentElementStyle);
      final BlockStyle childBlockStyle = await BlockStyle.getBlockStyle(
        child,
        elementStyle: childElementStyle,
        parentStyle: parentBlockStyle,
      );

      expect(childBlockStyle.alignment, LineAlignment.centre);
      expect(childBlockStyle.display, 'none');
    });
  });

  group('TableStyle.getTableStyle', () {
    test('should create and parse a table style', () async {
      cssParser.css['table'] = {
        'width': '75%',
        'table-layout': 'fixed',
      };

      final table = XmlElement(XmlName.parts('table'));
      final TableStyle tableStyle = await TableStyle.getTableStyle(table);

      expect(tableStyle.tableWidth, GetIt.instance.get<PageSize>().actualWidth * 0.75);
      expect(tableStyle.tableLayout, TableLayout.fixed);
    });

    test('should parse table background color', () async {
      cssParser.css['table'] = {
        'background-color': '#dbffe5',
      };

      final table = XmlElement(XmlName.parts('table'));
      final TableStyle tableStyle = await TableStyle.getTableStyle(table);

      expect(tableStyle.backgroundColor, const Color(0xFFDBFFE5));
    });
  });

  group('TableCellStyle.getTableCellStyle', () {
    test('should create and parse a table cell style', () async {
      cssParser.css['td'] = {
        'display': 'table-cell',
        'vertical-align': 'middle',
        'padding-top': '4px',
        'padding-bottom': '4px',
        'padding-left': '4px',
        'padding-right': '4px',
      };

      final XmlElement cell = XmlElement(XmlName.parts('td'));
      final ElementStyle elementStyle = await ElementStyle.getElementStyle(cell, null);
      final TableCellStyle tableCellStyle = await TableCellStyle.getTableCellStyle(
        cell,
        elementStyle: elementStyle,
      );

      expect(tableCellStyle.display, 'table-cell');
      expect(tableCellStyle.verticalAlignment, TableCellAlignment.middle);
      expect(tableCellStyle.paddingTop, 4);
      expect(tableCellStyle.paddingBottom, 4);
      expect(tableCellStyle.paddingLeft, 4);
      expect(tableCellStyle.paddingRight, 4);
    });
  });

  group('Integration tests', () {
    test('should match nth-child selectors in table descendant CSS', () async {
      cssParser.parseCss('''
        .recipe-table tbody tr:nth-child(odd) td { background-color: #f4fff7; }
        .recipe-table tbody tr:nth-child(even) td { background-color: #dbffe5; }
      ''');

      final table = XmlElement(XmlName.parts('table'))..setAttribute('class', 'recipe-table');
      final tbody = XmlElement(XmlName.parts('tbody'));
      final oddRow = XmlElement(XmlName.parts('tr'));
      final evenRow = XmlElement(XmlName.parts('tr'));
      final oddCell = XmlElement(XmlName.parts('td'));
      final evenCell = XmlElement(XmlName.parts('td'));

      oddRow.children.add(oddCell);
      evenRow.children.add(evenCell);
      tbody.children.add(oddRow);
      tbody.children.add(evenRow);
      table.children.add(tbody);

      final oddRowElementStyle = await ElementStyle.getElementStyle(oddRow, null);
      final evenRowElementStyle = await ElementStyle.getElementStyle(evenRow, null);
      final oddRowStyle = await TableRowStyle.getTableRowStyle(oddRow, elementStyle: oddRowElementStyle);
      final evenRowStyle = await TableRowStyle.getTableRowStyle(evenRow, elementStyle: evenRowElementStyle);

      oddRowStyle.getBackgroundColor(oddCell);
      evenRowStyle.getBackgroundColor(evenCell);

      expect(oddRowStyle.backgroundColor, const Color(0xFFF4FFF7));
      expect(evenRowStyle.backgroundColor, const Color(0xFFDBFFE5));
    });

    test('should handle complete CSS hierarchy', () {
      cssParser.parseCss('''
        h2 { color: black; font-size: 18px; }
        .title { color: blue; }
        h2.title { color: red; }
      ''');

      final element = XmlElement(XmlName.parts('h2'));
      element.setAttribute('class', 'title');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final color = cssParser.getStringAttribute(element, style, 'color');
      final fontSize = cssParser.getStringAttribute(element, style, 'font-size');

      expect(color, 'red');
      expect(fontSize, '18px');
    });

    test('should prioritize inline styles over everything', () {
      cssParser.parseCss('''
        h2 { color: black; }
        .title { color: blue; }
        h2.title { color: green; }
      ''');

      final element = XmlElement(XmlName.parts('h2'));
      element.setAttribute('class', 'title');
      element.setAttribute('style', 'color: red;');

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final color = cssParser.getStringAttribute(element, style, 'color');
      expect(color, 'red');
    });
  });

  group('@media blocks', () {
    test('drops rules inside an @media block whose type has not been enabled', () {
      cssParser.parseCss('@media amzn-mobi { p { color: red; } }');
      expect(cssParser.css['p'], isNull);
    });

    test('inlines rules inside an @media block once its type is enabled', () {
      cssParser.enableMedia('amzn-mobi');
      cssParser.parseCss('@media amzn-mobi { p { color: red; } }');
      expect(cssParser.css['p'], {'color': 'red'});
    });

    test('inlines every rule inside an enabled @media block, not just the first', () {
      cssParser.enableMedia('amzn-mobi');
      cssParser.parseCss('@media amzn-mobi { p { color: red; } h1 { color: blue; } }');
      expect(cssParser.css['p'], {'color': 'red'});
      expect(cssParser.css['h1'], {'color': 'blue'});
    });

    test('matches "type and (...)"-style media queries by their leading type name', () {
      cssParser.enableMedia('screen');
      cssParser.parseCss('@media screen and (max-width: 600px) { p { color: green; } }');
      expect(cssParser.css['p'], {'color': 'green'});
    });

    test('leaves rules outside the @media block untouched either way', () {
      cssParser.parseCss('@media amzn-mobi { p { color: red; } } h1 { color: gold; }');
      expect(cssParser.css['h1'], {'color': 'gold'});
      expect(cssParser.css['p'], isNull);
    });
  });

  group('parseFloatCssValue', () {
    test('should ignore a recognised unit outside px/pt/em/%, returning the raw numeric value', () {
      final result = cssParser.parseFloatCssValue('3vh', 100);
      expect(result, 3);
    });
  });

  group('getFontAttribute', () {
    test('should return only the first font in a comma-separated font-family list', () {
      cssParser.css['p'] = {'font-family': 'Georgia, serif'};
      final element = XmlElement(XmlName.parts('p'));

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final result = cssParser.getFontAttribute(element, style, 'font-family');
      expect(result, 'Georgia');
    });
  });

  group('getPercentAttribute', () {
    test('should return the fractional value of a percentage attribute', () {
      cssParser.css['div'] = {'max-width': '50%'};
      final element = XmlElement(XmlName.parts('div'));

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final result = cssParser.getPercentAttribute(element, style, 'max-width');
      expect(result, 0.5);
    });

    test('should return null when the attribute value is not a percentage', () {
      cssParser.css['div'] = {'max-width': '200px'};
      final element = XmlElement(XmlName.parts('div'));

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final result = cssParser.getPercentAttribute(element, style, 'max-width');
      expect(result, isNull);
    });
  });

  group('getFloatAttribute', () {
    test('strips a trailing !important from text-indent before parsing it as a length', () async {
      cssParser.css['p'] = {'text-indent': '20px !important'};
      final element = XmlElement(XmlName.parts('p'));

      ElementStyle style = ElementStyle();
      style.parseElement(element: element);
      final result = await cssParser.getFloatAttribute(element, 'text-indent', style, true);
      expect(result, 20);
    });
  });

  group('getFontWeight', () {
    test('should map every named numeric weight to its FontWeight', () {
      expect(cssParser.getFontWeight('500'), FontWeight.w500);
      expect(cssParser.getFontWeight('600'), FontWeight.w600);
      expect(cssParser.getFontWeight('800'), FontWeight.w800);
    });
  });

  group('nth-child selector matching', () {
    test('matches a numeric :nth-child(n), not just odd/even', () async {
      cssParser.parseCss('.list li:nth-child(2) { color: purple; }');

      final ul = XmlElement(XmlName.parts('ul'))..setAttribute('class', 'list');
      final li1 = XmlElement(XmlName.parts('li'));
      final li2 = XmlElement(XmlName.parts('li'));
      ul.children.addAll([li1, li2]);

      final li1Style = await ElementStyle.getElementStyle(li1, null);
      final li2Style = await ElementStyle.getElementStyle(li2, null);

      expect(cssParser.getStringAttribute(li1, li1Style, 'color'), isNull);
      expect(cssParser.getStringAttribute(li2, li2Style, 'color'), 'purple');
    });
  });

  group('BlockStyle margins and alignment', () {
    test('resolves explicit text-align values to their LineAlignment', () async {
      cssParser.css['p.left'] = {'text-align': 'left'};
      cssParser.css['p.right'] = {'text-align': 'right'};
      cssParser.css['p.justify'] = {'text-align': 'justify'};

      Future<LineAlignment?> alignmentFor(String className) async {
        final element = XmlElement(XmlName.parts('p'))..setAttribute('class', className);
        final elementStyle = await ElementStyle.getElementStyle(element, null);
        final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);
        return blockStyle.alignment;
      }

      expect(await alignmentFor('left'), LineAlignment.left);
      expect(await alignmentFor('right'), LineAlignment.right);
      expect(await alignmentFor('justify'), LineAlignment.justify);
    });

    test('centres a block via margin-left/margin-right: auto when text-align is unset', () async {
      cssParser.css['p'] = {'margin-left': 'auto', 'margin-right': 'auto'};
      final element = XmlElement(XmlName.parts('p'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      expect(blockStyle.alignment, LineAlignment.centre);
    });

    test('expands a single-value margin shorthand to all four sides', () async {
      cssParser.css['p'] = {'margin': '10px'};
      final element = XmlElement(XmlName.parts('p'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      expect(blockStyle.topMargin, 10);
      expect(blockStyle.bottomMargin, 10);
      expect(blockStyle.leftMargin, 10);
      expect(blockStyle.rightMargin, 10);
    });

    test('expands a two-value margin shorthand to vertical/horizontal pairs', () async {
      cssParser.css['p'] = {'margin': '10px 20px'};
      final element = XmlElement(XmlName.parts('p'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      expect(blockStyle.topMargin, 10);
      expect(blockStyle.bottomMargin, 10);
      expect(blockStyle.leftMargin, 20);
      expect(blockStyle.rightMargin, 20);
    });

    test('expands a three-value margin shorthand (top, sides, bottom)', () async {
      cssParser.css['p'] = {'margin': '10px 20px 30px'};
      final element = XmlElement(XmlName.parts('p'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      expect(blockStyle.topMargin, 10);
      expect(blockStyle.leftMargin, 20);
      expect(blockStyle.rightMargin, 20);
      expect(blockStyle.bottomMargin, 30);
    });

    test('expands a four-value margin shorthand (top, right, bottom, left)', () async {
      cssParser.css['p'] = {'margin': '10px 20px 30px 40px'};
      final element = XmlElement(XmlName.parts('p'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      expect(blockStyle.topMargin, 10);
      expect(blockStyle.rightMargin, 20);
      expect(blockStyle.bottomMargin, 30);
      expect(blockStyle.leftMargin, 40);
    });

    test('resolves percentage margins against the page canvas width', () async {
      cssParser.css['p'] = {'margin-left': '10%', 'margin-right': '5%'};
      final element = XmlElement(XmlName.parts('p'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      // canvasWidth is 600 in this suite's setUp.
      expect(blockStyle.leftMargin, 60);
      expect(blockStyle.rightMargin, 30);
    });

    test('resolves percentage margin-top/margin-bottom against the page canvas height', () async {
      cssParser.css['p'] = {'margin-top': '10%', 'margin-bottom': '5%'};
      final element = XmlElement(XmlName.parts('p'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      // canvasHeight is 800 in this suite's setUp.
      expect(blockStyle.topMargin, 80);
      expect(blockStyle.bottomMargin, 40);
    });

    test('resolves a percentage height against the page canvas height', () async {
      cssParser.css['div'] = {'height': '25%'};
      final element = XmlElement(XmlName.parts('div'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle);

      // canvasHeight is 800 in this suite's setUp.
      expect(blockStyle.height, 200);
    });
  });

  group('TableCellStyle padding shorthand', () {
    test('expands a single-value padding shorthand to all four sides', () async {
      cssParser.css['td'] = {'padding': '4px'};
      final element = XmlElement(XmlName.parts('td'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final cellStyle = await TableCellStyle.getTableCellStyle(element, elementStyle: elementStyle);

      expect(cellStyle.paddingTop, 4);
      expect(cellStyle.paddingBottom, 4);
      expect(cellStyle.paddingLeft, 4);
      expect(cellStyle.paddingRight, 4);
    });

    test('expands a four-value padding shorthand (top, right, bottom, left)', () async {
      cssParser.css['td'] = {'padding': '1px 2px 3px 4px'};
      final element = XmlElement(XmlName.parts('td'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final cellStyle = await TableCellStyle.getTableCellStyle(element, elementStyle: elementStyle);

      expect(cellStyle.paddingTop, 1);
      expect(cellStyle.paddingRight, 2);
      expect(cellStyle.paddingBottom, 3);
      expect(cellStyle.paddingLeft, 4);
    });

    test('a specific padding-left overrides the shorthand value for that side', () async {
      cssParser.css['td'] = {'padding': '4px', 'padding-left': '10px'};
      final element = XmlElement(XmlName.parts('td'));

      final elementStyle = await ElementStyle.getElementStyle(element, null);
      final cellStyle = await TableCellStyle.getTableCellStyle(element, elementStyle: elementStyle);

      expect(cellStyle.paddingLeft, 10);
      expect(cellStyle.paddingTop, 4);
    });
  });
}
