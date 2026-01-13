import 'package:injectable/injectable.dart';

import 'line.dart';
import 'line_listener.dart';

@LazySingleton()
class BuildLine {
  LineListener? _lineListener;
  Line currentLine = Line();

  set pageListener(LineListener? listener) => _lineListener = listener;
}