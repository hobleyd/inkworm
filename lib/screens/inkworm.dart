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
  final List<SharedMediaFile> _sharedFiles = [];

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
      // Listen to media sharing coming from outside the app while the app is in the memory.
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
        setState(() {
          _sharedFiles.clear();
          _sharedFiles.addAll(value);

          if (_sharedFiles.isNotEmpty) {
            GetIt.instance.get<EpubParser>().openBook(_sharedFiles.first.path);
          }
          print(_sharedFiles.map((f) => f.toMap()));
        });
      }, onError: (err) {
        print("getIntentDataStream error: $err");
      });

      // Get the media sharing coming from outside the app while the app is closed.
      ReceiveSharingIntent.instance.getInitialMedia().then((value) {
        setState(() {
          _sharedFiles.clear();
          _sharedFiles.addAll(value);

          if (_sharedFiles.isNotEmpty) {
            GetIt.instance.get<EpubParser>().openBook(_sharedFiles.first.path);
          }

          // Tell the library that we are done processing the intent.
          ReceiveSharingIntent.instance.reset();
        });
      });
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
                ? Text('${book.errorDescription}\n${book.error}')
                : PageCanvas(),),
            ProgressBar(),
          ],
        ),
      ),
    );
    }
}
