import 'dart:typed_data';

import 'package:get_it/get_it.dart';

import '../../../interfaces/isolate_parse_request.dart';
import '../../../interfaces/isolate_parse_response.dart';
import '../../epub_parser.dart';
import '../../font_management.dart';

class LoadFontRequest extends IsolateParseRequest {
  final String fontFamily;
  late Uint8List fontBytes;

  LoadFontRequest({super.id=1, required super.href, required this.fontFamily}) {
    // Knowing how the getBytes function works, strip out the relative paths as they won't be needed. Purists will disagree ;-)
    if (href.startsWith('url')) {
      href = href.substring(4, href.length-1);
    }
    String cleanedPath = href.replaceAll(RegExp(r'^(\.\.\/)+'), '');

    fontBytes = GetIt.instance.get<EpubParser>().getBytes(cleanedPath);
  }

  @override
  void init() {}

  @override
  Future<IsolateParseResponse> process(_) async {
    GetIt.instance.get<FontManagement>().loadFontFromEpub(fontFamily, fontBytes);

    // Not used; just for the interface definition.
    return IsolateParseResponse();
  }
}