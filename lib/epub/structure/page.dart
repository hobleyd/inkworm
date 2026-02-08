import 'package:get_it/get_it.dart';

import '../../models/page_size.dart';
import '../styles/block_style.dart';
import 'line.dart';

class Page {
  List<Line> lines = [];
  List<Line> footnotes = [];

  double dropCapsXPosition = 0;
  double dropCapsYPosition = 0;
  double currentBottomYPos = 0;
  double pageHeight = 0;

  Line?  get currentLine        => lines.lastOrNull;
  bool   get isCurrentLineEmpty => currentLine?.isEmpty ?? true;

  set alignment(LineAlignment alignment) => currentLine!.alignment = alignment;

  void addFootnote(Line line) {
    footnotes.add(line);
    PageSize size = GetIt.instance.get<PageSize>();
    pageHeight = size.canvasHeight - footnotes.totalHeight - 3;

    double footnotesYPos = pageHeight + 3;

    for (Line l in footnotes) {
      l.yPosOnPage = footnotesYPos;
      footnotesYPos += l.maxHeight;
    }
  }

  void addLine(Line line) {
    lines.add(line);
    currentBottomYPos += line.maxHeight;
  }

  bool willFitHeight(Line line) {
    if (pageHeight == 0) {
      PageSize size = GetIt.instance.get<PageSize>();
      pageHeight = size.canvasHeight;
    }

    return (currentBottomYPos + line.maxHeight) <= pageHeight;
  }
}