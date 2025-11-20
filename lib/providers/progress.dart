import 'package:inkworm/models/reading_progress.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'progress.g.dart';

@Riverpod(keepAlive: true)
class Progress extends _$Progress  {
  @override
  Future <ReadingProgress> build(String book) async {
    final SharedPreferencesAsync asyncPrefs = SharedPreferencesAsync();

    String? previousBook = await asyncPrefs.getString('book');
    int? chapter = await asyncPrefs.getInt('chapter');
    int? page = await asyncPrefs.getInt('page');

    if (previousBook == book) {
      if (chapter != null && page != null) {
        return ReadingProgress(chapterNumber: chapter, pageNumber: page);
      }
    }

    return ReadingProgress(chapterNumber: 0, pageNumber: 0);
  }

  Future<void> setProgress(String book, int chapter, int page) async{
    final SharedPreferencesAsync asyncPrefs = SharedPreferencesAsync();

    await asyncPrefs.setString('book', book);
    await asyncPrefs.setInt('chapter', chapter);
    await asyncPrefs.setInt('page', page);

    state = AsyncValue.data(ReadingProgress(chapterNumber: chapter, pageNumber: page));
  }
}