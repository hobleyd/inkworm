import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../styles/block_style.dart';
import 'line.dart';

class Page {
  List<Line> lines = [];

  double dropCapsXPosition = 0;
  double dropCapsYPosition = 0;
  double currentBottomYPos = 0;

  Line?  get currentLine        => lines.lastOrNull;
  bool   get isCurrentLineEmpty => currentLine?.isEmpty ?? true;

  set alignment(LineAlignment alignment) => currentLine!.alignment = alignment;

  void addLine(Line line) {
    lines.add(line);
    currentBottomYPos += line.maxHeight;
  }

  bool willFitHeight(Line line) {
    PageSize size = GetIt.instance.get<PageSize>();
    return (currentBottomYPos + line.maxHeight) <= size.canvasHeight;
  }
}