// One unit of work handed to a worker isolate.
import 'isolate_parse_response.dart';

abstract class IsolateParseRequest {
  const IsolateParseRequest({required this.id, required this.href});

  final int    id;
  final String href;

  Future<IsolateParseResponse> process();
}
