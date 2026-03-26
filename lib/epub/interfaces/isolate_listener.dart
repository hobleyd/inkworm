import '../../models/page_size.dart';
import '../structure/epub_chapter.dart';

abstract class IsolateListener {
  void onBookDetails(String author, String title, int spineLength);
  void onError(String error, String stackTrace);
  void onIsolatesInitialised();
  void onParsedChapter(EpubChapter chapter);
  void onSizeChanged(PageSize size);
}
