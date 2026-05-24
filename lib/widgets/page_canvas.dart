import 'dart:math' as math;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../epub/structure/epub_chapter.dart';
import '../epub/structure/line.dart';
import '../epub/structure/page.dart';
import '../models/page_size.dart';
import '../providers/epub.dart';
import '../models/epub_book.dart';
import '../models/reading_progress.dart';
import '../providers/progress.dart';
import '../providers/theme.dart';
import '../screens/settings.dart';
import 'page_renderer.dart';

class PageCanvas extends ConsumerStatefulWidget {
  const PageCanvas({super.key});

  @override
  ConsumerState<PageCanvas> createState() => _PageCanvas();
}

class _PageCanvas extends ConsumerState<PageCanvas> {
  static const EdgeInsets _pagePadding = EdgeInsets.only(top: 6, bottom: 6);
  static const double _handleRadius = 8;
  static const double _handleTouchRadius = 22; // larger hit target for handles

  final pageSize = GetIt.instance.get<PageSize>();
  int lastPageNumber = -1;

  // Selection state — null means no active selection.
  int? _selectionAnchor; // word index where long-press started
  int? _selectionFocus;  // word index of current drag target

  // true = left handle was dragged last (menu above); false = right or none (menu below).
  bool _menuAbove = false;

  // Canvas-coord positions tracked during handle drags.
  Offset? _leftDragPos;
  Offset? _rightDragPos;

  int? get _selectionStart => _selectionAnchor != null && _selectionFocus != null
      ? math.min(_selectionAnchor!, _selectionFocus!)
      : null;

  int? get _selectionEnd => _selectionAnchor != null && _selectionFocus != null
      ? math.max(_selectionAnchor!, _selectionFocus!)
      : null;

  bool get _hasSelection => _selectionAnchor != null;

  void _clearSelection() {
    _selectionAnchor = null;
    _selectionFocus = null;
    _menuAbove = false;
    _leftDragPos = null;
    _rightDragPos = null;
  }

  @override
  Widget build(BuildContext context) {
    EpubBook book = ref.watch(epubProvider);
    var progressAsync = ref.watch(progressProvider);

    return progressAsync.when(
        error: (error, stackTrace) {
          return const Text('');
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        data: (ReadingProgress progress) {
          Future(() => ref.read(themeProvider.notifier).setFontSize(progress.fontSize.toDouble()));

          final EpubChapter? chapter = book.chapters.elementAtOrNull(progress.chapterNumber);
          int pageNumber = progress.pageNumber >= 0 ? progress.pageNumber : 0;
          if (chapter != null && chapter.pages.isNotEmpty && pageNumber >= chapter.pages.length) {
            pageNumber = chapter.pages.length - 1;
          }

          // Clear selection when the page changes.
          if (lastPageNumber != progress.pageNumber && _hasSelection) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_clearSelection);
            });
          }

          final page = chapter == null || chapter.pages.isEmpty ? null : chapter[pageNumber];
          final List<Line> lines = page?.lines ?? [];
          final List<Line> foots = page?.footnotes ?? [];
          final backgrounds = page?.backgrounds ?? [];
          final List<LinkHitArea> links = page?.links ?? [];
          final List<WordHitArea> words = page?.words ?? [];

          PageRenderer renderer = PageRenderer(
            lines: lines,
            footnotes: foots,
            backgrounds: backgrounds,
            words: words,
            selectionStart: _selectionStart,
            selectionEnd: _selectionEnd,
          );

          if (lastPageNumber != progress.pageNumber && lines.isNotEmpty) {
            renderer.needsRepaint = true;
            setState(() {
              lastPageNumber = progress.pageNumber;
            });
          }

          return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth != pageSize.canvasWidth || constraints.maxHeight - _pagePadding.vertical != pageSize.canvasHeight) {
                  pageSize.update(canvasWidth: constraints.maxWidth, canvasHeight: constraints.maxHeight - _pagePadding.vertical);
                }

                return Container(
                  padding: _pagePadding,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTapUp: (TapUpDetails details) {
                          if (_hasSelection) {
                            setState(_clearSelection);
                            return;
                          }

                          // Check link hit areas first; localPosition maps to canvas coordinates.
                          for (final link in links) {
                            if (link.rect.contains(details.localPosition)) {
                              ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, link.chapterIndex, 0);
                              return;
                            }
                          }

                          double screenWidth = MediaQuery.of(context).size.width;
                          double tapX = details.globalPosition.dx;

                          if (tapX < screenWidth * 0.33) {
                            if (progress.pageNumber > 0) {
                              ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, progress.chapterNumber, progress.pageNumber - 1);
                            } else if (progress.chapterNumber > 0) {
                              final int ch = progress.chapterNumber - 1;
                              ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, ch, book[ch].lastPageIndex);
                            }
                          } else if (tapX > screenWidth * 0.66) {
                            if (progress.pageNumber >= book[progress.chapterNumber].lastPageIndex) {
                              if (progress.chapterNumber < book.lastChapterIndex) {
                                ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, progress.chapterNumber + 1, 0);
                              } else {
                                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                              }
                            } else {
                              ref.read(progressProvider.notifier).setProgress(book.uri, progress.fontSize, progress.chapterNumber, progress.pageNumber + 1);
                            }
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => Settings())).then((onValue) {});
                          }
                        },
                        onLongPressStart: (LongPressStartDetails details) {
                          final idx = page?.wordIndexNearestTo(details.localPosition);
                          if (idx != null) {
                            setState(() {
                              _selectionAnchor = idx;
                              _selectionFocus = idx;
                              _menuAbove = false;
                            });
                          }
                        },
                        onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
                          if (_selectionAnchor == null) return;
                          final idx = page?.wordIndexNearestTo(details.localPosition);
                          if (idx != null) {
                            setState(() {
                              _selectionFocus = idx;
                            });
                          }
                        },
                        child: CustomPaint(painter: renderer),
                      ),
                      if (_hasSelection && _selectionStart != null && _selectionEnd != null && words.isNotEmpty) ...[
                        ..._buildHandles(words, page!, progress, book),
                        _buildMenu(words, constraints.maxHeight - _pagePadding.vertical),
                      ],
                    ],
                  ),
                );
              },
          );
        });
  }

  List<Widget> _buildHandles(List<WordHitArea> words, Page page, ReadingProgress progress, EpubBook book) {
    final lo = _selectionStart!;
    final hi = _selectionEnd!;

    if (lo >= words.length || hi >= words.length) return [];

    final leftWordRect  = words[lo].rect;
    final rightWordRect = words[hi].rect;

    // Handle anchors in canvas coordinates (below the word rect).
    final leftAnchor  = Offset(leftWordRect.left,   leftWordRect.bottom + _handleRadius);
    final rightAnchor = Offset(rightWordRect.right, rightWordRect.bottom + _handleRadius);

    return [
      _buildHandle(
        anchorInCanvas: leftAnchor,
        isLeft: true,
        page: page,
        wordCount: words.length,
      ),
      _buildHandle(
        anchorInCanvas: rightAnchor,
        isLeft: false,
        page: page,
        wordCount: words.length,
      ),
    ];
  }

  Rect _selectionBounds(List<WordHitArea> words) {
    final lo = _selectionStart!.clamp(0, words.length - 1);
    final hi = _selectionEnd!.clamp(0, words.length - 1);
    Rect bounds = words[lo].rect;
    for (int i = lo + 1; i <= hi; i++) {
      bounds = bounds.expandToInclude(words[i].rect);
    }
    return bounds;
  }

  Widget _buildMenu(List<WordHitArea> words, double canvasHeight) {
    const double menuHeight = 44;
    final double menuWidth  = _selectionStart == _selectionEnd ? 104 : 52; // one or two icon buttons
    const double aboveGap   = 8;
    const double belowGap   = _handleRadius * 2 + 6; // clear the handle circles
    const double edgeMargin = 8;

    final Rect sel = _selectionBounds(words);

    // Decide whether to show above or below, flipping if too close to the edge.
    // If neither fits, overlay the menu on the first line of the selection.
    bool above = _menuAbove;
    if (above  && sel.top    < menuHeight + aboveGap) above = false;
    if (!above && sel.bottom + belowGap + menuHeight > canvasHeight) above = true;

    final bool fitsAbove = sel.top    >= menuHeight + aboveGap;
    final bool fitsBelow = sel.bottom + belowGap + menuHeight <= canvasHeight;

    final double menuTop;
    if (fitsAbove || fitsBelow) {
      menuTop = above
          ? sel.top - aboveGap - menuHeight
          : sel.bottom + belowGap;
    } else {
      // No clear space: overlay on the first line (left handle) or last line (right handle).
      menuTop = _menuAbove
          ? words[_selectionStart!].rect.top
          : words[_selectionEnd!].rect.top;
    }

    double menuLeft = sel.center.dx - menuWidth / 2;
    menuLeft = menuLeft.clamp(edgeMargin, pageSize.canvasWidth - menuWidth - edgeMargin);

    final String text = words
        .sublist(_selectionStart!, _selectionEnd! + 1)
        .map((w) => w.text)
        .join(' ');

    return Positioned(
      left: menuLeft,
      top:  menuTop,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: menuHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectionStart == _selectionEnd)
                IconButton(
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: 'Dictionary',
                  onPressed: () {
                    _lookupInDictionary(text);
                    setState(_clearSelection);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: () {
                  _shareText(text);
                  setState(_clearSelection);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _lookupInDictionary(String text) async {
    final uri = Uri.parse('https://en.wiktionary.org/wiki/${Uri.encodeComponent(text.trim())}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareText(String text) async {
    await Share.share(text.trim());
  }

  Widget _buildHandle({
    required Offset anchorInCanvas,
    required bool isLeft,
    required Page page,
    required int wordCount,
  }) {
    return Positioned(
      left: anchorInCanvas.dx - _handleTouchRadius,
      top:  anchorInCanvas.dy - _handleTouchRadius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          if (isLeft) {
            _leftDragPos = anchorInCanvas;
            _menuAbove = true;
          } else {
            _rightDragPos = anchorInCanvas;
            _menuAbove = false;
          }
        },
        onPanUpdate: (details) {
          if (isLeft) {
            _leftDragPos = (_leftDragPos ?? anchorInCanvas) + details.delta;
            final idx = page.wordIndexNearestTo(_leftDragPos!);
            if (idx != null) {
              setState(() {
                // Left handle controls the lower selection boundary.
                final newStart = idx.clamp(0, _selectionEnd!);
                if (newStart <= _selectionEnd!) {
                  _selectionAnchor = newStart;
                  _selectionFocus  = _selectionEnd!;
                }
              });
            }
          } else {
            _rightDragPos = (_rightDragPos ?? anchorInCanvas) + details.delta;
            final idx = page.wordIndexNearestTo(_rightDragPos!);
            if (idx != null) {
              setState(() {
                // Right handle controls the upper selection boundary.
                final newEnd = idx.clamp(_selectionStart!, wordCount - 1);
                if (newEnd >= _selectionStart!) {
                  _selectionAnchor = _selectionStart!;
                  _selectionFocus  = newEnd;
                }
              });
            }
          }
        },
        child: SizedBox(
          width:  _handleTouchRadius * 2,
          height: _handleTouchRadius * 2,
        ),
      ),
    );
  }
}
