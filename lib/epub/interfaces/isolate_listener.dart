import '../../models/page_size.dart';
import '../structure/epub_chapter.dart';

abstract class IsolateListener {
  void onBookDetails(String author, String title, int spineLength);
  void onComplete();
  void onError(String error, String stackTrace);
  void onInitialised(bool workerState);
  void onParsedChapter(EpubChapter chapter);
  void onSizeChanged(PageSize size);
  void onSizeReceived();
}
