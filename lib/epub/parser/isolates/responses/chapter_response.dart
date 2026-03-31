
import '../../../interfaces/isolate_parse_response.dart';
import '../../../structure/epub_chapter.dart';

class ChapterResponse extends IsolateParseResponse {
  final EpubChapter chapter;

  ChapterResponse({required this.chapter});

}