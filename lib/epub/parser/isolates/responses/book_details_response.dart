import '../../../interfaces/isolate_parse_response.dart';

class BookDetailsResponse extends IsolateParseResponse {
  final String author;
  final String title;
  final int    length;

  BookDetailsResponse({required this.author, required this.title, required this.length});

}