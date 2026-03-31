import 'dart:isolate';
import 'dart:typed_data';

import 'package:get_it/get_it.dart';

import '../../../../models/element_size.dart';
import '../../../cache/image_cache.dart';
import '../../../interfaces/isolate_parse_request.dart';
import '../../../interfaces/isolate_parse_response.dart';

class MeasureImageRequest extends IsolateParseRequest {
  final Uint8List imageBytes;
  final SendPort port;

  MeasureImageRequest({super.id=1, required super.href, required this.imageBytes, required this.port});

  @override
  void init() {}

  @override
  Future<IsolateParseResponse> process(_) async {
    ImageCache cache = GetIt.instance.get<ImageCache>();

    if (!cache.isCached(href)) {
      await cache.addImage(href, imageBytes);
    }
    port.send(ElementSize(ascent: 0, descent: 0, width: cache[href].width.toDouble(), height: cache[href].height.toDouble()));

    // Not used; just for the interface definition.
    return IsolateParseResponse();
  }
}