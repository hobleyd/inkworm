import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_progress.freezed.dart';

@freezed
class ReadingProgress with _$ReadingProgress {
  @override
  final int chapterNumber;

  @override
  final int pageNumber;

  const ReadingProgress({required this.chapterNumber, required this.pageNumber});

  @override
  String toString() {
    return 'Chapter: $chapterNumber / Page: $pageNumber';
  }
}