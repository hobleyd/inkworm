import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/page_renderer.dart';

class Inkworm extends ConsumerStatefulWidget {
  int pageNumber = 0;
  Inkworm({super.key, required this.pageNumber});

  @override
  ConsumerState<Inkworm> createState() => _Inkworm();
}

class _Inkworm extends ConsumerState<Inkworm> {
  int displayedPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: GestureDetector(
              onTapUp: (TapUpDetails details) {
                double screenWidth = MediaQuery.of(context).size.width;
                double tapX = details.globalPosition.dx;

                setState(() {
                  if (tapX < screenWidth / 2) {
                    if (displayedPage > 0) {
                      displayedPage--;
                    }
                  } else {
                    // TODO: deal with end of chapter!
                    displayedPage++;
                  }
                });
                    },
            child: CustomPaint(
              painter: PageRenderer(ref, displayedPage),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    displayedPage = widget.pageNumber;
  }
}
