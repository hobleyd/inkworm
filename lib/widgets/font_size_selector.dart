import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';


import '../models/page_size.dart';
import '../models/reading_progress.dart';
import '../providers/epub.dart';
import '../providers/font_size.dart';
import '../providers/progress.dart';
import '../providers/theme.dart' hide Theme;

class FontSize extends ConsumerStatefulWidget {
  const FontSize({super.key,});

  @override
  ConsumerState<FontSize> createState() => _FontSize();
}

class _FontSize extends ConsumerState<FontSize> {
  ReadingProgress? progress;
  int fontSize = 12;
  bool setDefaultFont = false;

  @override
  Widget build(BuildContext context) {
    PageSize size = GetIt.instance.get<PageSize>();
    var progressAsync = ref.watch(progressProvider);

    if (progressAsync.hasValue) {
      progress = progressAsync.value;
      fontSize = progress!.fontSize;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsGeometry.only(left: size.leftIndent, bottom: 12),
          child: Text('Select your preferred font size:', style: Theme.of(context).textTheme.labelMedium),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(9, (index) {
              int fontSize = 12 + index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(themeProvider.notifier).setFontSize(fontSize.toDouble());
                    setState(() {
                      this.fontSize = fontSize;
                      _setFontSize();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: progress?.fontSize == fontSize ? Colors.blue : Colors.grey[300],
                    foregroundColor: progress?.fontSize == fontSize ? Colors.white : Colors.black,
                  ),
                  child: Text('${fontSize}pt', style: TextStyle(fontSize: fontSize.toDouble()),),
                ),
              );
            },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsetsGeometry.only(left: size.leftIndent, top: 12, bottom: 12),
          child: CheckboxListTile(
            value: setDefaultFont,
            onChanged: (bool? setDefault) {
              setState(() {
                setDefaultFont = setDefault!;
                if (setDefaultFont) {
                  _setFontSize();
                }
              });
            },
            title: Text('Make this the new default', style: Theme.of(context).textTheme.labelMedium),
          ),
        ),
      ],
    );
  }

  void _setFontSize() {
    if (progress != null) {
      ref.read(progressProvider.notifier).setProgress(progress!.book, fontSize, progress!.chapterNumber, progress!.pageNumber);
      ref.read(epubProvider.notifier).openBook(progress!.book);

      if (setDefaultFont) {
        ref.read(fontSizeProvider.notifier).setDefaultFontSize(fontSize);
      }
    }
  }
}