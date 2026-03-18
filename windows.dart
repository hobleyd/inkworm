import 'dart:io';

import 'package:innosetup/innosetup.dart';
import 'package:version/version.dart';

void main() {
  final version = Version.parse(Platform.environment['VERSION']!);
  final issPath = 'build/windows/inkworm-${Platform.environment["VERSION"]}.iss';

  // Let the package generate the base .iss file as normal.
  InnoSetup(
    app: InnoSetupApp(
      name: 'Inkworm',
      version: version,
      publisher: 'author',
      urls: InnoSetupAppUrls(
        homeUrl: Uri.parse('https://sharpblue.com.au/'),
      ),
    ),
    files: InnoSetupFiles(
      executable: File('build/windows/x64/runner/Release/inkworm.exe'),
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

  // Append registry entries for .epub file association.
  // The package does not expose a registry API so we patch the .iss directly.
  _appendRegistrySection(issPath);

  // Re-run iscc on the patched script so the registry entries are included.
  _recompile(issPath);
}

void _appendRegistrySection(String issPath) {
  final file = File(issPath);
  if (!file.existsSync()) {
    throw StateError('Expected generated .iss file not found: $issPath');
  }

  // Patch [Setup] to add ChangesAssociations=yes (required for Explorer to
  // refresh file-type icons without a reboot).
  var contents = file.readAsStringSync();
  if (!contents.contains('ChangesAssociations')) {
    contents = contents.replaceFirst(
      '[Setup]',
      '[Setup]\nChangesAssociations=yes',
    );
  }

  // Append the [Registry] section if it isn't already there.
  if (!contents.contains('[Registry]')) {
    contents += '''

[Registry]
; Associate .epub extension with Inkworm
Root: HKCR; Subkey: ".epub";                           ValueType: string; ValueName: ""; ValueData: "au.com.sharpblue.Inkworm.epub"; Flags: uninsdeletevalue
; File-type display name shown in Explorer
Root: HKCR; Subkey: "au.com.sharpblue.Inkworm.epub";  ValueType: string; ValueName: ""; ValueData: "EPUB Document";               Flags: uninsdeletekey
; Icon — use the app icon (index 0) as the file-type icon
Root: HKCR; Subkey: "au.com.sharpblue.Inkworm.epub\\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\\inkworm.exe,0"
; Open command — passes the file path as argv[1]
Root: HKCR; Subkey: "au.com.sharpblue.Inkworm.epub\\shell\\open\\command"; ValueType: string; ValueName: ""; ValueData: """{app}\\inkworm.exe"" ""%1"""
''';
  }

  file.writeAsStringSync(contents);
  print('Patched $issPath with [Registry] section.');
}

void _recompile(String issPath) {
  // iscc.exe must be on PATH, or adjust the path below.
  // The package's own .make() already ran iscc once; we run it again on the
  // patched script to produce the final installer with registry entries baked in.
  const iscc = 'iscc';
  print('Re-compiling $issPath ...');
  final result = Process.runSync(iscc, [issPath], runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(iscc, [issPath],
        'iscc failed with exit code ${result.exitCode}', result.exitCode);
  }
  print('Done.');
}