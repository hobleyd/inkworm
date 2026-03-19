/// One unit of work handed to a worker isolate.
class IsolateParseRequest {
  const IsolateParseRequest({required this.id, required this.href});

  final int    id;
  final String href;
}
