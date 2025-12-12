import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/reading_db.dart';
import '../../models/reading_progress.dart';

part 'progress.g.dart';

@Riverpod(keepAlive: true)
class Progress extends _$Progress  {
  @override
  Future <ReadingProgress> build() async {
    var readingHistory = ref.read(readingDBProvider.notifier);
    ReadingProgress saved = await readingHistory.getReadingProgress(null);

    ReadingProgress progress = GetIt.instance.get<ReadingProgress>();
    progress.book          = saved.book;
    progress.fontSize      = saved.fontSize;
    progress.chapterNumber = saved.chapterNumber;
    progress.pageNumber    = saved.pageNumber;

    return progress;
  }

  Future<void> setProgress(String book, int fontSize, int chapter, int page) async {
    ReadingProgress progress = GetIt.instance.get<ReadingProgress>();
    if (progress.book != book || progress.fontSize != fontSize || progress.chapterNumber != chapter || progress.pageNumber != page) {
      var readingHistory = ref.read(readingDBProvider.notifier);

      progress.book          = book;
      progress.fontSize      = fontSize;
      progress.chapterNumber = chapter;
      progress.pageNumber    = page;

      readingHistory.setProgress(progress);

      state = AsyncValue.data(progress.copyWith(book: book, fontSize: fontSize, chapterNumber: chapter, pageNumber: page));
    }
  }
}