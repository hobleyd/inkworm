import 'dart:io';

import 'package:android_package_installer/android_package_installer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkworm/providers/epub.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../models/version_check.dart';
import '../../providers/update.dart';

class InkwormUpdate extends ConsumerStatefulWidget {
  const InkwormUpdate({super.key,});

  @override
  ConsumerState<InkwormUpdate> createState() => _InkwormUpdate();
}

class _InkwormUpdate extends ConsumerState<InkwormUpdate> {
  bool downloading = false;
  bool checkingVersion = false;
  double? downloadProgress;

  @override
  Widget build(BuildContext context) {
    VersionCheck? versions = ref.watch(updateProvider).value;

    if (downloading) {
      final int progressPercentage = ((downloadProgress ?? 0) * 100).round();

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: downloadProgress),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Downloading update... $progressPercentage%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ]
      );
    } else if (versions == null) {
      final String noUpdateLabel = Platform.isAndroid
          ? 'There are no updates for Inkworm as at this time.'
          : 'Only Android is supported for in-application updates at this time.';

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(padding: EdgeInsetsGeometry.only(top: 30), child: Text(noUpdateLabel, style: Theme.of(context).textTheme.labelMedium)),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildCheckVersionAction(),
          ),
        ],
      );
    } else {
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
                padding: EdgeInsetsGeometry.only(top: 30),
                child: Text('Installed Version: ${versions.currentVersion}', style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text('Current Version: ${versions.newVersion}', style: Theme.of(context).textTheme.bodyMedium),
            if (versions.hasUpdate)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: IconButton(icon: const Icon(Icons.download), onPressed: () => _download(ref, versions.downloadUrl, versions.downloadPackage)),
              ),
            if (!versions.hasUpdate)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _buildCheckVersionAction(),
              ),
          ]
      );
    }
  }

  Widget _buildCheckVersionAction() {
    if (checkingVersion) {
      return Column(
        children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2),),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Checking for updates...', style: Theme.of(context).textTheme.bodyMedium,),
          ),
        ],
      );
    }

    return IconButton(icon: const Icon(Icons.refresh), onPressed: _checkVersion,);
  }

  Future<void> _checkVersion() async {
    setState(() {
      checkingVersion = true;
    });

    try {
      await ref.read(updateProvider.notifier).checkVersion();
    } finally {
      if (mounted) {
        setState(() {
          checkingVersion = false;
        });
      }
    }
  }

  Future<void> _download(WidgetRef ref, String url, String package) async {
    setState(() {
      downloading = true;
      downloadProgress = 0;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = path.join(tempDir.path, package);

      await Dio().download(
        url,
        apkPath,
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) {
            return;
          }

          setState(() {
            downloadProgress = received / total;
          });
        },
      );

      final int? statusCode = await AndroidPackageInstaller.installApk(apkFilePath: apkPath,);
      if (statusCode == null) {
        ref.read(epubProvider.notifier).setError('Android did not return an installation result.', StackTrace.current);
        return;
      }

      final installationStatus = PackageInstallerStatus.byCode(statusCode);
      if (installationStatus != PackageInstallerStatus.success) {
        ref.read(epubProvider.notifier).setError('Update install failed: ${installationStatus.name}.', StackTrace.current);
      }
    } on DioException catch (error) {
      ref.read(epubProvider.notifier).setError('Update download failed: ${error.message ?? 'network error'}.', StackTrace.current);
    } catch (error) {
      ref.read(epubProvider.notifier).setError('Update failed: $error', StackTrace.current);
    } finally {
      if (mounted) {
        setState(() {
          downloading = false;
          downloadProgress = null;
        });
      }
    }
  }
}
