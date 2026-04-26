import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:version/version.dart';

import '../models/version_check.dart';

part 'update.g.dart';

@riverpod
class Update extends _$Update {
  @override
  Future<VersionCheck?> build() async {
    return _checkGithub();
  }

  Future<void> checkVersion() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_checkGithub);
  }

  Future<VersionCheck?> _checkGithub() async {
    if (!Platform.isAndroid) return null;

    final response = await Dio().get('https://api.github.com/repos/hobleyd/inkworm/releases/latest');
    if (response.statusCode != 200) return null;

    final List<dynamic> assets = response.data['assets'] as List<dynamic>;
    if (assets.isEmpty) return null;

    final Version githubVersion = Version.parse(response.data['tag_name'] as String);
    final String url   = assets.first['browser_download_url'] as String;
    final String name  = assets.first['name'] as String;

    final pubspec = await rootBundle.loadString("pubspec.yaml");
    final Version buildVersion = Version.parse(pubspec.split("version: ")[1].split("\n")[0].trim());

    return VersionCheck(currentVersion: buildVersion, newVersion: githubVersion, downloadUrl: url, downloadPackage: name);
  }
}