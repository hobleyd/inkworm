import 'dart:io';

import 'package:innosetup/innosetup.dart';
import 'package:version/version.dart';

void main() {
  InnoSetup(
    app: InnoSetupApp(
      name: 'Inkworm',
      version: Version.parse(Platform.environment['VERSION']!),
      publisher: 'author',
      urls: InnoSetupAppUrls(
        homeUrl: Uri.parse('https://sharpblue.com.au/'),
      ),
    ),
    files: InnoSetupFiles(
      executable: File('build/windows/x64/runner/Release/inkworm.exe '),
      location: Directory('build/windows/x64/runner/Release'),
    ),
    name: InnoSetupName('inkworm-${Platform.environment["VERSION"]}'),
    location: InnoSetupInstallerDirectory(
      Directory('build/windows'),
    ),
    icon: InnoSetupIcon(
      File('assets/inkworm.ico'),
    ),
  ).make();
}