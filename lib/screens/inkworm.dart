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
  String bookPath = "";

  // Shared channel name — must match the C++ side.
  static const _fileChannel = MethodChannel('au.com.sharpblue.inkworm/file');

  @override
  Widget build(BuildContext context) {
    EpubBook book = ref.watch(epubProvider);
    var asyncDb = ref.watch(readingDBProvider);

    if (bookPath.isEmpty && book.uri.isNotEmpty) {
      bookPath = book.uri;
    }

    if (bookPath.isNotEmpty) {
      Future(() => ref.read(epubProvider.notifier).openBook(bookPath));
    }

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

    switch (Platform.operatingSystem) {
      case "android":
        _handleAndroidIntent();
        break;
      case "macos":
        _handleMacOSIntent();
        break;
      case "windows":
        _handleWindowsIntent();
        break;
      case "linux":
        _handleLinuxIntent();
        break;
      default:
        setState(() {
          bookPath = Platform.environment['EBOOK']!;
        });
        break;
    }
  }

  void _handleAndroidIntent() async {
    // Listen for Intents coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        setState(() {
          bookPath = value.first.path;
        });
      }
    }, onError: (e, s) {
      ref.read(epubProvider.notifier).setError(e.toString(), s);
    },);

    // Get Intents coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        setState(() {
          bookPath = value.first.path;
        });
      }

      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _handleLinuxIntent() async {
    const platform = MethodChannel('au.com.sharpblue.inkworm/file');
    try {
      final String? filePath = await platform.invokeMethod('getOpenedFile');
      if (filePath != null && filePath.isNotEmpty) {
        setState(() {
          bookPath = filePath;
        });
      }
    } catch (e, s) {
      ref.read(epubProvider.notifier).setError(e.toString(), s);
    }
  }

  Future<void> _handleMacOSIntent() async {
    FileOpen.onOpened.listen((uris) {
      setState(() {
        bookPath = uris.first.toFilePath();
      });
    });
  }

  Future<void> _handleWindowsIntent() async {
    // 1. Get the file path passed on the command line at launch (the common
    //    case: user double-clicks an .epub or uses "Open with…").
    try {
      final String? filePath = await _fileChannel.invokeMethod('getOpenedFile');
      if (filePath != null && filePath.isNotEmpty) {
        setState(() {
          bookPath = filePath;
        });
      }
    } catch (e, s) {
      ref.read(epubProvider.notifier).setError(e.toString(), s);
    }

    // 2. Listen for files opened while the app is already running.
    //    The C++ side posts these via setMethodCallHandler.
    _fileChannel.setMethodCallHandler((call) async {
      if (call.method == 'fileOpened') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          setState(() {
            bookPath = path;
          });
        }
      }
    });
  }
}
