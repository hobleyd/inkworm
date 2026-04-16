import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/providers/book_state_management.dart';


import '../models/book_state.dart';
import '../models/page_size.dart';
import '../models/reading_progress.dart';
import '../providers/epub.dart';
import '../providers/progress.dart';
import '../providers/theme.dart' hide Theme;
import 'default_font_size_checkbox.dart';

class FontSize extends ConsumerStatefulWidget {
  const FontSize({super.key,});

  @override
  ConsumerState<FontSize> createState() => _FontSize();
}

class _FontSize extends ConsumerState<FontSize> {
  int fontSize = 12;
  bool setDefaultFont = false;

  @override
  Widget build(BuildContext context) {
    PageSize size = GetIt.instance.get<PageSize>();
    BookState bookState = ref.watch(bookStateManagementProvider);

    var progressAsync = ref.watch(progressProvider);
    return progressAsync.when(error: (error, stackTrace) {
      return const Text("It's time to panic; we can't make any progress!");
    }, loading: () {
      return const Center(child: CircularProgressIndicator());
    }, data: (var progress) {
      fontSize = progress.fontSize;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bookState.hasAll(BookState.complete))
            ...[
              Padding(
                padding: EdgeInsetsGeometry.only(left: size.leftIndent, bottom: 12, top: 32),
                child: Text('Select your preferred font size:', style: Theme.of(context).textTheme.labelMedium),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: _getSizedFontRow(12, 6, progress),),
              SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: _getSizedFontRow(18, 6, progress),),
              DefaultFontSizeCheckbox(selectedFontSize: progress.fontSize,),
            ],
          if (bookState.hasNone(BookState.complete)) Padding(
            padding: EdgeInsetsGeometry.only(left: size.leftIndent, bottom: 12, top: 64),
            child: Text("Please wait until Book parsing is complete before changing font size.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      );
    });
  }

  List<Widget> _getSizedFontRow(int start, int length, ReadingProgress progress) {
    return List.generate(length, (index) {
      int fontSize = start + index;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () {
            BookState bookState = ref.read(bookStateManagementProvider);
            if (bookState.hasAny(BookState.complete)) {
              ref.read(themeProvider.notifier).setFontSize(fontSize.toDouble());
              setState(() {
                this.fontSize = fontSize;
              });

            _setFontSize(progress.copyWith(book: progress.book, fontSize: fontSize, chapterNumber: progress.chapterNumber, pageNumber: 0));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: progress.fontSize == fontSize ? Colors.blue : Colors.grey[300],
            foregroundColor: progress.fontSize == fontSize ? Colors.white : Colors.black,
          ),
          child: Text('${fontSize}pt', style: TextStyle(fontSize: fontSize.toDouble()),),
        ),
      );
    });
  }

  void _setFontSize(ReadingProgress progress) async {
    // Reset page to 0 as they'll change with a different font size.

      await ref.read(progressProvider.notifier).setProgress(progress.book, progress.fontSize, progress.chapterNumber, progress.pageNumber);
      ref.read(epubProvider.notifier).resetBook(progress.book);

  }
}