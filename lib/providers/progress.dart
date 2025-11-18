import 'package:inkworm/models/reading_progress.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress.g.dart';

@Riverpod(keepAlive: true)
class Progress extends _$Progress  {
  ReadingProgress build() {
    return ReadingProgress(chapterNumber: 0, pageNumber: 0);
  }

  void setProgress(int chapter, int page) {
    state = ReadingProgress(chapterNumber: chapter, pageNumber: page);
  }
}