import 'package:injectable/injectable.dart';

@Singleton()
class LinkCache {
  final Set<String> _linkCache = {};

  void add(String? link) {
    if (link != null) {
      _linkCache.add(link);
    }
  }

  bool contains(String? link) {
    if (link != null) {
      return _linkCache.contains(link);
    }

    // Return true if null as we don't want to process it.
    return true;
  }
}