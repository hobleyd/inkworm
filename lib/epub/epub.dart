import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'epub_chapter.dart';

part 'epub.g.dart';

@Riverpod(keepAlive: true)
class Epub extends _$Epub {
  String book = "x";

  final List<EpubChapter> _chapters = [];

  @override
  List<EpubChapter> build() {
    return [];
  }

  operator [](int index) => _chapters[index];

  void addText(TextSpan span) {
    if (_chapters.isEmpty) {
      _chapters.add(EpubChapter(chapterNumber: 0));
    }

    _chapters.last.addTextToCurrentPage(span);
  }

  void clear() {
    for (var chapter in _chapters) {
      chapter.clear();
    }

    _chapters.clear();
  }

  Future<void> parse(BuildContext context, String filename) async {
    clear();

    book = filename;
    addText(
        TextSpan(text: """The cutter passed from sunlit brilliance to soot-black shadow with the knife-edge suddenness possible only in space, and the tall, broad-shouldered woman in the black and gold of the Royal Manticoran Navy gazed out the armorplast port at the battle-steel beauty of her command and frowned.""",
            style: Theme.of(context).textTheme.bodySmall!));
    addText(
        TextSpan(text: """
The six-limbed cream-and-gray treecat on her shoulder shifted his balance as she raised her right hand and pointed.
    """, style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
    addText(
        TextSpan(text: """
"I thought we'd discussed replacing Beta Fourteen with Commander Antrim, Andy," she said, and the short, dapper lieutenant commander beside her winced at her soprano voice's total lack of inflection.    """, style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
    addText(
        TextSpan(text: """
"Yes, Ma'am. We did." He tapped keys on his memo pad and checked the display. "We discussed it on the sixteenth, Skipper, before you went on leave, and he promised to get back to us."
    """, style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
    addText(
        TextSpan(text: """
"You've had a lot of other things on your plate, too," she said, and Andreas Venizelos hid another—and much more painful—wince. Honor Harrington seldom rapped her officers in the teeth, but he would almost have preferred to have her hand him his head. Her quiet, understanding tone sounded entirely too much as if she were finding excuses for him.    """,
            style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
    addText(
        TextSpan(text: """
"Maybe so, Ma'am, but I still should've kept after him," he said. "We both know how these yard types hate node replacements." He tapped a note into his pad. "I'll com him as soon as we get back aboard Vulcan."
""", style: Theme.of(context)
            .textTheme
            .bodySmall!));

    state = List.from(_chapters);
  }


}