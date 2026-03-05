import 'package:injectable/injectable.dart';

import '../epub/interfaces/isolate_listener.dart';

// Required to avoid trying to pass the epubProvider through the isolate which will fail.

@lazySingleton
class PageSizeIsolateListener {
  IsolateListener? isolateListener;

  PageSizeIsolateListener();

  void setListener(IsolateListener listener) {
    isolateListener = listener;
  }
}