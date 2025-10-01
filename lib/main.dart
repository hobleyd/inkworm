import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'config/provider_logger.dart';
import 'inkworm_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

  Logger.level = Level.error;

  runApp(ProviderScope(
      observers: [ProviderLogger()],
      child: const InkwormApp()));
}
