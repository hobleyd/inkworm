import 'package:flutter/foundation.dart';

@immutable
class ManifestItem {
  final String href;
  final String mimeType;

  const ManifestItem({required this.href, required this.mimeType});

  @override
  String toString() {
    return 'href=$href, mimeType=$mimeType';
  }
}