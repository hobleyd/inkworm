import 'package:xml/xml.dart';

import '../../models/element_size.dart';
import '../content/html_content.dart';
import '../content/text_content.dart';
import '../parser/isolates/worker_slot.dart';
import '../styles/block_style.dart';
import '../styles/element_style.dart';
import 'html_handler.dart';

class TextHandler extends HtmlHandler {
  TextHandler() {
    HtmlHandler.registerHandler(XmlNodeType.TEXT.name.toLowerCase(), this);
  }

  @override
  Future<List<HtmlContent>> processElement({required XmlNode node, BlockStyle? parentBlockStyle, ElementStyle? parentElementStyle}) async {
    XmlText element = node as XmlText;

    List<HtmlContent> elements = [];

    final List<String> words = _splitString(_collapseNewlines(element.value));

    // Some (older, Calibre-converted) epubs use a block containing nothing but a &nbsp; as a paragraph
    // spacer, sized with an explicit CSS `height` (e.g. `height: 6px`), instead of paragraph margins.
    // Without this, that &nbsp; is measured at the surrounding font's normal line height, turning what
    // should be a small spacer into a full extra blank line. Only apply the block's height when the
    // node is nothing but whitespace filler - real text must keep its measured height.
    final bool isWhitespaceFiller = words.every((word) => word == ' ' || word == '\u{00A0}');
    final double? fillerHeight = isWhitespaceFiller ? parentBlockStyle?.height : null;

    for (String word in words) {
      ElementSize size = await WorkerSlot.measureTextInMainThread(word, parentElementStyle!.textStyle);
      elements.add(TextContent(blockStyle: parentBlockStyle!, elementStyle: parentElementStyle, text: word, ascent: size.ascent, descent: size.descent, height: fillerHeight ?? size.height, width: size.width));
    }

    return elements;
  }

  // Embedded newlines/tabs get glued onto the adjacent word and mismeasured by TextPainter
  // (which treats \n as a hard break); collapse them to a space per HTML whitespace rules.
  String _collapseNewlines(String span) => span.replaceAll(RegExp(r'[\t\n\r]+'), ' ');

  List<String> _splitString(String span) {
    List<String> tokens = [];
    String current = "";

    for (int i = 0; i < span.length; i++) {
      String char = span[i];

      if (char == '-' || char == '\u{2014}' || char == ' ' || char == '\u{00A0}') {
        if (current.isNotEmpty) {
          tokens.add(current);
          current = "";
        }
        tokens.add(char);
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      tokens.add(current);
    }

    return _mergeSpacedEllipsis(tokens);
  }

  // Collapses "word ( |&nbsp;).(  |&nbsp;)." patterns into "word..." so that
  // typewriter-style spaced ellipses are kept together with their preceding word.
  List<String> _mergeSpacedEllipsis(List<String> tokens) {
    List<String> result = [];
    int i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      final isSeparator = token == ' ' || token == '\u{00A0}' || token == '-' || token == '\u{2014}';
      if (!isSeparator) {
        int j = i + 1;
        String dots = '';
        while (j + 1 < tokens.length &&
               (tokens[j] == ' ' || tokens[j] == '\u{00A0}') &&
               tokens[j + 1] == '.') {
          dots += '.';
          j += 2;
        }
        if (dots.isNotEmpty) {
          result.add(token + dots);
          i = j;
          continue;
        }
      }
      result.add(token);
      i++;
    }
    return result;
  }

}