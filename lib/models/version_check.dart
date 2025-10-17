import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:version/version.dart';

@immutable
class VersionCheck {
  final Version currentVersion;
  final Version newVersion;
  final String downloadUrl;
  final String downloadPackage;

  bool get hasUpdate => newVersion > currentVersion;

  const VersionCheck({required this.currentVersion, required this.newVersion, required this.downloadUrl, required this.downloadPackage});
}