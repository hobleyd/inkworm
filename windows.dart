import 'dart:io';

import 'package:version/version.dart';

void main() {
  final version = Version.parse(Platform.environment['VERSION']!);
  final versionStr = Platform.environment['VERSION']!;
  final issPath = 'build/windows/inkworm-$versionStr.iss';

  _writeIssFile(issPath, version, versionStr);
  _compile(issPath);
}

void _writeIssFile(String issPath, Version version, String versionStr) {
  final iss = '''
[Setup]
AppName=Inkworm
AppVersion=$version
AppPublisher=SharpBlue
AppPublisherURL=https://sharpblue.com.au/
AppSupportURL=https://sharpblue.com.au/
AppUpdatesURL=https://sharpblue.com.au/
DefaultDirName={autopf}\\Inkworm
DefaultGroupName=Inkworm
OutputDir=.
OutputBaseFilename=inkworm-$versionStr
SetupIconFile=inkworm.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "x64\\runner\\Release\\inkworm.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\Inkworm";    Filename: "{app}\\inkworm.exe"
Name: "{group}\\Uninstall Inkworm"; Filename: "{uninstallexe}"
Name: "{autodesktop}\\Inkworm"; Filename: "{app}\\inkworm.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\\inkworm.exe"; Description: "{cm:LaunchProgram,Inkworm}"; Flags: nowait postinstall skipifsilent

[Registry]
; Associate .epub extension with Inkworm
Root: HKCR; Subkey: ".epub";                                                  ValueType: string; ValueName: ""; ValueData: "au.com.sharpblue.Inkworm.epub"; Flags: uninsdeletevalue
; File-type display name shown in Explorer
Root: HKCR; Subkey: "au.com.sharpblue.Inkworm.epub";                          ValueType: string; ValueName: ""; ValueData: "EPUB Document";                Flags: uninsdeletekey
; Icon
Root: HKCR; Subkey: "au.com.sharpblue.Inkworm.epub\\DefaultIcon";             ValueType: string; ValueName: ""; ValueData: "{app}\\inkworm.exe,0"
; Open command
Root: HKCR; Subkey: "au.com.sharpblue.Inkworm.epub\\shell\\open\\command";    ValueType: string; ValueName: ""; ValueData: """{app}\\inkworm.exe"" ""%1"""
''';

  File(issPath).writeAsStringSync(iss);
}

void _compile(String issPath) {
  try {
    const iscc = 'iscc';
    final result = Process.runSync(iscc, [issPath], runInShell: true);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      throw ProcessException(iscc, [issPath], 'iscc failed with exit code ${result.exitCode}', result.exitCode);
    }
    print('Done.');
  } catch (e, s) {
    print('Failed: $e\n$s');
  }
}