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
    state = AsyncValue.data(await _checkGithub());
  }

  Future<VersionCheck?> _checkGithub() async {
    if (Platform.isAndroid) {
      try {
        final response = await Dio().get('https://api.github.com/repos/hobleyd/inkworm/releases/latest');
        if (response.statusCode == 200) {
          final Version githubVersion = Version.parse(response.data['tag_name']);
          final String url = response.data['assets'].first['browser_download_url'];

          final pubspec = await rootBundle.loadString("pubspec.yaml");
          final Version buildVersion = Version.parse(pubspec.split("version: ")[1].split("\n")[0]);

          return VersionCheck(currentVersion: buildVersion, newVersion: githubVersion, downloadUrl: url, downloadPackage: response.data['assets'].first['name']);
        }
      } catch (e) {
        return null;
      }
    }

    return null;
  }
}