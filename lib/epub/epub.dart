import 'package:flutter/material.dart';
import 'package:inkworm/epub/epub_chapter.dart';

class Epub  {
  String book = "x";
  double canvasHeight = 0;
  double canvasWidth = 0;
  double leftIndent = 12;
  double rightIndent = 12;

  final List<EpubChapter> _chapters = [];

  Epub._();
  static final instance = Epub._();

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

  void parse(BuildContext context, String filename) {
    clear();

    book = filename;
    addText(
        TextSpan(text: """
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis pharetra lobortis faucibus. Vestibulum efficitur, velit nec accumsan aliquam, lectus elit congue nulla, ac venenatis purus mi vel risus. Ut auctor consequat nibh in sodales. Aenean eget dolor dictum, imperdiet turpis nec, interdum diam. Sed vitae mauris hendrerit, tempus orci sit amet, placerat eros. Nulla dignissim, orci quis congue maximus, eros arcu mattis magna, vitae interdum lacus lorem nec velit. Aliquam a diam at metus pulvinar efficitur. Fusce in augue eget ligula pharetra iaculis. Nunc id dui in magna aliquet hendrerit. Nullam eu enim lacus.
    """,
            style: Theme
                .of(context)
                .textTheme
                .bodySmall!));
    addText(
        TextSpan(text: """
    Nullam aliquam elementum velit vel tincidunt. Cras dui ex, lobortis sit amet tortor ut, rutrum maximus tortor. Nulla faucibus tellus nisi, non dapibus nisi aliquam sed. Morbi sed dignissim libero. Fusce dignissim leo nec libero placerat, id consectetur augue interdum. Praesent ut massa nisl. Praesent id pulvinar ex. In egestas nec ligula et blandit.
    """, style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
    addText(
        TextSpan(text: """
    Cras sed finibus diam. Quisque odio nisl, fermentum et ante vitae, sollicitudin sodales risus. Mauris varius semper lectus, id gravida nibh sodales eget. Pellentesque aliquam, velit quis fringilla rhoncus, neque orci semper tellus, quis interdum odio justo sit amet dui. Nam tristique aliquam purus, in facilisis lacus facilisis sed. Nullam pulvinar ultrices molestie. Cras ac erat porta enim bibendum semper.
    """, style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
    addText(
        TextSpan(text: """
    Curabitur sed dictum sem, et sollicitudin dolor. Sed semper elit est, at fermentum purus bibendum nec. Donec scelerisque diam sit amet ante cursus cursus in scelerisque tellus. Pellentesque nec nibh id mi euismod efficitur in ac lorem. Pellentesque scelerisque fermentum vestibulum. Cras molestie lobortis dolor vel faucibus. Vivamus hendrerit est vitae tellus commodo accumsan. Phasellus ut finibus nulla. Nam sed massa turpis.
    """, style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
    addText(
        TextSpan(text: """
    Mauris nec nunc ex. Morbi pellentesque scelerisque ligula, vel accumsan ligula rutrum nec. Pellentesque quis nulla ligula. Duis diam arcu, iaculis nec sem sit amet, malesuada consectetur arcu. Ut a nisi faucibus, pulvinar nisl sit amet, dignissim eros. Ut tortor metus, bibendum a congue fermentum, efficitur sed nisl. Donec vel placerat magna, in placerat ligula. Sed dignissim pulvinar mauris non tristique.
    """, style: Theme
            .of(context)
            .textTheme
            .bodySmall!));
  }

  void setConstraints({required double height, required double width}) {
    if (height != canvasHeight || width != canvasWidth) {
      canvasHeight = height;
      canvasWidth = width;
    }
  }
}