
import '../../../interfaces/isolate_parse_response.dart';
import '../../extensions.dart';

class OpenedResponse extends IsolateParseResponse {
  final Map<String, CssDeclarations> css;

  OpenedResponse({ required this.css });
}