import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pages.g.dart';

@Riverpod(keepAlive: true)
class Pages extends _$Pages {
  late BoxConstraints _constraints;

  @override
  void build() {
    _constraints = BoxConstraints(maxWidth: RootContext, maxHeight: );
    return;
  }

  List<Widget> _chapterPages = List.empty(growable:true);
  int _fontSize = 12;
  String _fontFamily = "Roboto";
  String _text ="aaaaaa \n\n aaaaa";

  void addText(TextSpan span) {
    TextPainter painter = TextPainter(text: span, maxLines: null, textScaleFactor: 1, textDirection: TextDirection.ltr,);
    painter.layout(maxWidth: _constraints.maxWidth);

    final overflowHeight = painter.size.height > _constraints.maxHeight;

    double charWidth = 0.48 * _fontSize; // TODO: this coefficient is dodgy
    double charHeight = painter.preferredLineHeight;
    int charInLine = _constraints.maxWidth ~/ charWidth;
    int lines = _constraints.maxHeight ~/ charHeight;

    // cut string base on rough estimate of characters allowed in BoxConstraints
    if (overflowHeight) {
      int splitStart = (charInLine * lines).toInt();
      String newText = span.text!.substring(0, splitStart);

      // do final calculation for char allowed in boxconstraint SS
      splitStart = getSplitIndex(constraints: BoxConstraints, text: newText, style: span.style!);

      final String nextText = span.text!.substring(splitStart, span.text!.length);
      addText(TextSpan(text: nextText, style: span.style!));
    }

    var newPage = SingleChildScrollView(
      child: Container(
        // color: overflowH ? Colors.red : Colors.green,
        child: Text.rich(
          span,
          style: style,
          textAlign: TextAlign.justify,
        ),
      ),
    );

    _chapterPages.add(newPage);
  }
  int getSplitIndex({required BoxConstraints constraints, required String text, required style}) {
    // debugPrint("textSubstring: ${newText}");

    int splitStart = text.length;
    TextSpan span = TextSpan(
      text: text,
      style: style,
    );

    // cek if painter still exceed constraints
    var painter = TextPainter(
      text: span,
      maxLines: null,
      textScaleFactor: 1,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: constraints.maxWidth);

    final overFlowH = painter.height > constraints.maxHeight;

    if (!overFlowH) return splitStart;

    //check paragraph
    List<RegExpMatch> listParagraph = getListParagraphRegMatch(text);
    if (listParagraph.length > 1) {
      splitStart = listParagraph[listParagraph.length - 2].end;
      debugPrint('lastParagraph: $splitStart');
      text = text.substring(0, splitStart);
      return getSplitIndex(constraints: constraints, text: text, style: style);
    }

    return splitStart;
  }

  List<RegExpMatch> getListParagraphRegMatch(String newText) {
    RegExp regExp = RegExp(r"((?:[^\n][\n]?)+)", multiLine: true,);

    if (newText.isNotEmpty) return regExp.allMatches(newText).toList();
    return [];
  }

}