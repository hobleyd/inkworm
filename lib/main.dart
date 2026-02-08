import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:window_manager/window_manager.dart';

import 'config/provider_logger.dart';
import 'inkworm_app.dart';

import 'main.config.dart';

@injectableInit
void configureInjection() => GetIt.instance.init();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureInjection();
  await windowManager.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

  Logger.level = Level.error;

  WindowOptions windowOptions = WindowOptions(
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ProviderScope(
      observers: [ProviderLogger()],
      child: const InkwormApp()));
}
