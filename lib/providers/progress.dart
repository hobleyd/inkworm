import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/reading_progress.dart';

part 'progress.g.dart';

@Riverpod(keepAlive: true)
class Progress extends _$Progress  {
  @override
  Future <ReadingProgress> build() async {
    final SharedPreferencesAsync asyncPrefs = SharedPreferencesAsync();

    String? book = await asyncPrefs.getString('book');
    int? chapter = await asyncPrefs.getInt('chapter');
    int? page = await asyncPrefs.getInt('page');

    ReadingProgress progress = GetIt.instance.get<ReadingProgress>();
    progress.book          = book ?? "";
    progress.chapterNumber = chapter ?? 0;
    progress.pageNumber    = page ?? 0;

    debugPrint('built progressProvider: $progress');
    return progress;
  }

  Future<void> setProgress(String book, int chapter, int page) async {
    ReadingProgress progress = GetIt.instance.get<ReadingProgress>();
    if (progress.book != book || progress.chapterNumber != chapter || progress.pageNumber != page) {
      final SharedPreferencesAsync asyncPrefs = SharedPreferencesAsync();

      await asyncPrefs.setString('book', book);
      await asyncPrefs.setInt('chapter', chapter);
      await asyncPrefs.setInt('page', page);

      progress.book          = book;
      progress.chapterNumber = chapter;
      progress.pageNumber    = page;

      state = AsyncValue.data(progress.copyWith(book: book, chapterNumber: chapter, pageNumber: page));
    }
  }
}