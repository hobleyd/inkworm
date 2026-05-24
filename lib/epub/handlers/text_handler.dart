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

    for (String word in _splitString(element.value)) {
      ElementSize size = await WorkerSlot.measureTextInMainThread(word, parentElementStyle!.textStyle);
      elements.add(TextContent(blockStyle: parentBlockStyle!, elementStyle: parentElementStyle, text: word, ascent: size.ascent, descent: size.descent, height: size.height, width: size.width));
    }

    return elements;
  }

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