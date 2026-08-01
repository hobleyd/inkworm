import 'dart:math';

import 'package:xml/xml.dart';

import '../../models/element_size.dart';
import '../content/html_content.dart';
import '../content/paragraph_break.dart';
import '../content/text_content.dart';
import '../parser/extensions.dart';
import '../parser/isolates/worker_slot.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

class ListHandler extends HtmlHandler {
  // assets/default.css indents <ul>/<ol> via `-moz-padding-start: 40px`, but this renderer has no
  // padding concept - so each list level adds this much to marginLeft instead, on top of whatever
  // indent its ancestors already accumulated. Halved from the CSS default at the user's request.
  static const String _defaultIndent = '20px';

  // How much wider than a single space the gap between a marker and its item's text should be.
  static const double _markerGapMultiplier = 1.5;

  ListHandler() {
    HtmlHandler.registerHandler('ul', this);
    HtmlHandler.registerHandler('ol', this);
    HtmlHandler.registerHandler('li', this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlElement element = node as XmlElement;

    ElementStyle elementStyle = await ElementStyle.getElementStyle(element, parentElementStyle);
    BlockStyle blockStyle = await BlockStyle.getBlockStyle(element, elementStyle: elementStyle, parentStyle: parentBlockStyle);

    if (blockStyle.display == "none") {
      return [];
    }

    if (element.localName == 'li') {
      return _processListItem(element: element, blockStyle: blockStyle, elementStyle: elementStyle, parentBlockStyle: parentBlockStyle);
    }

    return _processList(element: element, blockStyle: blockStyle, elementStyle: elementStyle, parentBlockStyle: parentBlockStyle);
  }

  Future<List<HtmlContent>> _processList({required XmlElement element, required BlockStyle blockStyle, required ElementStyle elementStyle, BlockStyle? parentBlockStyle}) async {
    final double indent = await blockStyle.parser.getFloatFromString(elementStyle.textStyle, _defaultIndent, true) ?? 0;
    blockStyle.leftMargin = (parentBlockStyle?.marginLeft ?? 0) + indent;
    blockStyle.rightMargin = (parentBlockStyle?.marginRight ?? 0) + indent;

    return _buildBlock(element: element, blockStyle: blockStyle, elementStyle: elementStyle);
  }

  // The marker ("1." / "•") is synthesised text, not something in the chapter's own markup - browsers
  // generate it from list-style-type via a UA stylesheet, which this renderer doesn't model. We give the
  // <li> a marginLeft that includes the marker's width, so marker, wrapped lines, and any block-level
  // children all sit at the indent where the text starts. The marker itself hangs to the left of that on
  // the first line only, via a negative text-indent applied to a *separate* copy of the blockStyle used
  // solely for the leading ParagraphBreak - not the shared blockStyle passed to children. leftIndent is
  // inherited by CSS convention (`copyFrom` passes it straight to child blocks), so if the negative value
  // lived on the shared blockStyle, a block-level first child (`<li><p>...</p></li>`, common in
  // Calibre-produced EPUBs) would inherit it and render off the left edge of the page.
  Future<List<HtmlContent>> _processListItem({required XmlElement element, required BlockStyle blockStyle, required ElementStyle elementStyle, BlockStyle? parentBlockStyle}) async {
    final XmlElement? list = element.parentElement;
    final bool isOrdered = list?.localName == 'ol';

    final String markerWord = isOrdered
        ? await _ordinalWord(item: element, list: list!, listStyle: parentBlockStyle)
        : _bulletWord(list: list, listStyle: parentBlockStyle);

    final List<HtmlContent> marker = [];
    double markerWidth = 0;

    if (markerWord.isNotEmpty) {
      final ElementSize wordSize = await WorkerSlot.measureTextInMainThread(markerWord, elementStyle.textStyle);
      final double gutterWidth = list == null
          ? wordSize.width
          : await _markerGutterWidth(list: list, isOrdered: isOrdered, listStyle: parentBlockStyle, elementStyle: elementStyle);
      final ElementSize spaceSize = await WorkerSlot.measureTextInMainThread('\u{00A0}', elementStyle.textStyle);
      final double gapWidth = spaceSize.width * _markerGapMultiplier;
      markerWidth = gutterWidth + gapWidth;

      // One WordElement (marker glyph + trailing space, box widened to cover the whole gap) rather than
      // marker-word-plus-separate-space-Separator: a Separator is stretched by `Line.calculateSeparatorWidth`
      // to fill a justified line. That would silently widen just this gap (it's on line 1, the only line
      // that gets justified), while the static gap baked into blockStyle.leftMargin for wrapped lines stays
      // unstretched - so wrapped lines would land left of where line 1's actual (stretched) text starts.
      // Folding the gap into the word's own box keeps it a fixed width regardless of justification; a plain
      // space (not nbsp) is fine here since the gap can't be broken independently either way - it's fused
      // into this one atomic element.
      marker.add(TextContent(blockStyle: blockStyle, elementStyle: elementStyle, text: '$markerWord ', ascent: wordSize.ascent, descent: wordSize.descent, height: wordSize.height, width: markerWidth));
    }

    blockStyle.leftMargin = (parentBlockStyle?.marginLeft ?? 0) + markerWidth;
    blockStyle.rightMargin = parentBlockStyle?.marginRight ?? 0;

    BlockStyle? leadingBreakStyle;
    if (markerWord.isNotEmpty) {
      leadingBreakStyle = blockStyle.copyWith(bottomMargin: 0);
      leadingBreakStyle.leftIndent = -markerWidth;
    }

    return _buildBlock(element: element, blockStyle: blockStyle, elementStyle: elementStyle, leading: marker, leadingBreakStyle: leadingBreakStyle);
  }

  // Mirrors BlockHandler's block-building loop (leading/trailing ParagraphBreak, margin collapsing between
  // adjacent breaks) so <ul>/<ol>/<li> behave like any other block, with an optional marker spliced in first.
  Future<List<HtmlContent>> _buildBlock({required XmlElement element, required BlockStyle blockStyle, required ElementStyle elementStyle, List<HtmlContent> leading = const [], BlockStyle? leadingBreakStyle}) async {
    final List<HtmlContent> elements = [
      ParagraphBreak(blockStyle: leadingBreakStyle ?? blockStyle.copyWith(bottomMargin: 0), elementStyle: elementStyle, width: 0, height: 0),
      ...leading,
    ];

    for (var child in element.children) {
      if (child.shouldProcess && !isEmptyParagraph(child)) {
        List<HtmlContent>? childElements = await child.handler?.processElement(node: child, parentBlockStyle: blockStyle, parentElementStyle: elementStyle);
        if (childElements?.isNotEmpty ?? false) {
          for (var el in childElements!) {
            if (el is ParagraphBreak && elements.last is ParagraphBreak) {
              if (el.marginTop > 0 && elements.last.marginBottom > 0) {
                el.blockStyle.topMargin = max(elements.last.marginBottom, el.marginTop);
                elements.removeLast();
              }
            }
            elements.add(el);
          }
        }
      }
    }

    elements.add(ParagraphBreak(blockStyle: blockStyle.copyWith(topMargin: 0), elementStyle: elementStyle, width: 0, height: 0));

    return elements;
  }

  // Every item in a list must reserve the same gutter width, or items land at different text-start x
  // positions - most visibly with ordinal markers, since digits are rarely all the same width in a
  // proportional font ("1" commonly renders narrower than "2"-"9") and a longer list can mix single- and
  // double-digit ordinals. Bullets don't vary item-to-item (same character every time), so only <ol> needs
  // the full per-item scan; reuse this item's own already-measured width there instead of remeasuring.
  Future<double> _markerGutterWidth({required XmlElement list, required bool isOrdered, required BlockStyle? listStyle, required ElementStyle elementStyle}) async {
    if (!isOrdered) {
      final ElementSize size = await WorkerSlot.measureTextInMainThread(_bulletWord(list: list, listStyle: listStyle), elementStyle.textStyle);
      return size.width;
    }

    double maxWidth = 0;
    for (final item in list.children.whereType<XmlElement>().where((e) => e.localName == 'li')) {
      final String word = await _ordinalWord(item: item, list: list, listStyle: listStyle);
      if (word.isEmpty) continue;

      final ElementSize size = await WorkerSlot.measureTextInMainThread(word, elementStyle.textStyle);
      if (size.width > maxWidth) maxWidth = size.width;
    }

    return maxWidth;
  }

  Future<String> _ordinalWord({required XmlElement item, required XmlElement list, BlockStyle? listStyle}) async {
    final List<XmlElement> items = list.children.whereType<XmlElement>().where((e) => e.localName == 'li').toList();
    final int start = int.tryParse(list.getAttribute('start') ?? '') ?? 1;
    final int ordinal = start + items.indexOf(item);

    final String? style = list.getAttribute('type') ?? listStyle?.parser.getStringAttribute(list, listStyle, 'list-style-type');

    return switch (style) {
      'a' || 'lower-alpha' || 'lower-latin' => '${_alpha(ordinal, upper: false)}.',
      'A' || 'upper-alpha' || 'upper-latin' => '${_alpha(ordinal, upper: true)}.',
      'i' || 'lower-roman'                  => '${_roman(ordinal, upper: false)}.',
      'I' || 'upper-roman'                  => '${_roman(ordinal, upper: true)}.',
      'none'                                => '',
      _                                     => '$ordinal.',
    };
  }

  String _bulletWord({XmlElement? list, BlockStyle? listStyle}) {
    final String? style = (list == null || listStyle == null) ? null : listStyle.parser.getStringAttribute(list, listStyle, 'list-style-type');

    return switch (style) {
      'circle' => '\u{25E6}',
      'square' => '\u{25AA}',
      'none'   => '',
      _        => '\u{2022}',
    };
  }

  // Bijective base-26: 1=a .. 26=z, 27=aa, 28=ab, ...
  String _alpha(int n, {required bool upper}) {
    String result = '';
    while (n > 0) {
      n--;
      result = String.fromCharCode((upper ? 65 : 97) + (n % 26)) + result;
      n ~/= 26;
    }
    return result;
  }

  String _roman(int n, {required bool upper}) {
    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const numerals = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];

    String result = '';
    for (int i = 0; i < values.length; i++) {
      while (n >= values[i]) {
        result += numerals[i];
        n -= values[i];
      }
    }

    return upper ? result : result.toLowerCase();
  }
}
