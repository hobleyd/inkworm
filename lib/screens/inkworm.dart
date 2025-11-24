import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:inkworm/epub/constants.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../epub/epub.dart';
import '../epub/parser/epub_parser.dart';
import '../models/epub_book.dart';
import '../widgets/page_canvas.dart';
import '../widgets/progress_bar.dart';

class Inkworm extends ConsumerStatefulWidget {
  const Inkworm({super.key,});

  @override
  ConsumerState<Inkworm> createState() => _Inkworm();
}

class _Inkworm extends ConsumerState<Inkworm> {
  late StreamSubscription _intentSub;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
      // Listen to media sharing coming from outside the app while the app is in the memory.
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
          if (value.isNotEmpty) {
              GetIt.instance.get<EpubParser>().openBook(value.first.path);
          }
        }, onError: (e, s) {
          ref.read(epubProvider.notifier).setError(e.toString(), s);
        },
      );

      // Get the media sharing coming from outside the app while the app is closed.
      ReceiveSharingIntent.instance.getInitialMedia().then((value) {
        if (value.isNotEmpty) {
          GetIt.instance.get<EpubParser>().openBook(value.first.path);
        }

        ReceiveSharingIntent.instance.reset();
      });
    } else {
      GetIt.instance.get<EpubParser>().openBook(Platform.environment['EBOOK']!);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _intentSub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    EpubBook book = ref.watch(epubProvider);

    MediaQueryData data = MediaQueryData.fromView(View.maybeOf(context)!);
    PageConstants.pixelDensity = data.devicePixelRatio;

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: book.error != null || book.errorDescription != null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Text('${book.errorDescription}\n${book.error}', style: Theme.of(context).textTheme.bodyMedium),)
                  : PageCanvas(),
            ),
            ProgressBar(),
          ],
        ),
      ),
    );
    }
}
