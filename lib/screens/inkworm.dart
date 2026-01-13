import 'dart:async';
import 'dart:io';

import 'package:file_open/file_open.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../database/reading_db.dart';
import '../models/epub_book.dart';
import '../models/page_size.dart';
import '../providers/epub.dart';
import '../widgets/fatal_error.dart';
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
  Widget build(BuildContext context) {
    EpubBook book = ref.watch(epubProvider);
    var asyncDb = ref.watch(readingDBProvider);

    MediaQueryData data = MediaQueryData.fromView(View.maybeOf(context)!);
    PageSize size = GetIt.instance.get<PageSize>();
    size.update(pixelDensity: data.devicePixelRatio);

    return asyncDb.when(error: (error, stackTrace) {
      return const Text("It's time to panic; we can't open the database!");
    }, loading: () {
      return const Center(child: CircularProgressIndicator());
    }, data: (var db) {
      return Scaffold(
        appBar: null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: book.error != null || book.errorDescription != null ? FatalError() : PageCanvas(),
              ),
              ProgressBar(),
            ],
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _intentSub.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
      _handleAndroidIntent();
    } else if (Platform.isMacOS) {
      _handleMacOSIntent();
    } /*else if (Platform.isLinux) {
      _handleLinuxIntent();
    }*/ else {
      // TODO: Support other platforms for debugging.
      Future(() {
        ref.read(epubProvider.notifier).openBook(Platform.environment['EBOOK']!);
      });
    }
  }

  void _handleAndroidIntent() async {
    // Listen for Intents coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        ref.read(epubProvider.notifier).openBook(value.first.path);
      }
    }, onError: (e, s) {
      ref.read(epubProvider.notifier).setError(e.toString(), s);
    },);

    // Get Intents coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        ref.read(epubProvider.notifier).openBook(value.first.path);
      }

      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _handleLinuxIntent() async {
    const platform = MethodChannel('au.com.sharpblue.inkworm/file');
    try {
      final String? filePath = await platform.invokeMethod('getOpenedFile');
      if (filePath != null && filePath.isNotEmpty) {
        debugPrint('Linux - Received EPUB: $filePath');
        ref.read(epubProvider.notifier).openBook(filePath);
      }
    } catch (e, s) {
      ref.read(epubProvider.notifier).setError(e.toString(), s);
    }
  }

  Future<void> _handleMacOSIntent() async {
    FileOpen.onOpened.listen((uris) {
      ref.read(epubProvider.notifier).openBook(uris.first.toFilePath());
      return;
    });
  }
}
