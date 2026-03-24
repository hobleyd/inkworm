import 'package:inkworm/epub/structure/epub_chapter.dart';

/// The result produced by a worker isolate for one [IsolateParseRequest].
class IsolateParseResponse {
  final String? error;
  final String? stacktrace;

  const IsolateParseResponse({this.error, this.stacktrace});

  bool get hasError => error != null;

  @override
  String toString() => hasError
      ? 'IsolateParseResponse(error: $error)'
      : 'IsolateParseResponse()';
}