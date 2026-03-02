import 'package:injectable/injectable.dart';

import '../epub/interfaces/isolate_listener.dart';

@lazySingleton
class PageSizeIsolateListener {
  IsolateListener? isolateListener;

  PageSizeIsolateListener();

  void setListener(IsolateListener listener) {
    isolateListener = listener;
  }
}