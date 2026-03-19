import 'package:inkworm/epub/structure/epub_chapter.dart';

/// The result produced by a worker isolate for one [IsolateParseRequest].
class IsolateParseResponse {
  const IsolateParseResponse({required this.id, this.chapter, this.error});

  final int          id;
  final EpubChapter? chapter; // expand with real parsed fields
  final String?      error;

  bool get hasError => error != null;

  @override
  String toString() => hasError
      ? 'EpubParseResult($id, error: $error)'
      : 'EpubParseResult($id, title: ${chapter?.chapterNumber})';
}