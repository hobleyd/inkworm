import 'dart:io';

import 'package:android_package_installer/android_package_installer.dart';
import 'package:desktop_updater/desktop_updater.dart';
import 'package:desktop_updater/updater_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/version_check.dart';
import '../providers/epub.dart';
import '../providers/update.dart';

class InkwormUpdate extends ConsumerStatefulWidget {
  const InkwormUpdate({super.key,});

  @override
  ConsumerState<InkwormUpdate> createState() => _InkwormUpdate();
}

class _InkwormUpdate extends ConsumerState<InkwormUpdate> {
  bool downloading = false;
  double? downloadProgress;
  DesktopUpdaterController? _desktopController;

  static const String _appArchiveUrl = 'https://hobleyd.github.io/inkworm/app-archive.json';

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      _desktopController = DesktopUpdaterController(
        appArchiveUrl: Uri.parse(_appArchiveUrl),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return ListenableBuilder(
        listenable: _desktopController!,
        builder: (context, _) {
          if (_desktopController!.needUpdate) {
            return DesktopUpdateDirectCard(
              controller: _desktopController!,
              child: const SizedBox.shrink(),
            );
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Text('There are no updates for Inkworm at this time.', style: Theme.of(context).textTheme.labelMedium),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: IconButton(icon: const Icon(Icons.refresh), onPressed: _desktopController!.checkVersion),
              ),
            ],
          );
        },
      );
    }

    final updateState = ref.watch(updateProvider);

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
    }

    if (updateState.isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Checking for updates...'),
          ),
        ],
      );
    }

    if (updateState.hasError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Text('Update check failed: ${updateState.error}', style: Theme.of(context).textTheme.labelMedium),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildCheckVersionAction(),
          ),
        ],
      );
    }

    final VersionCheck? versions = updateState.value;

    if (versions == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(padding: const EdgeInsets.only(top: 30), child: Text('There are no updates for Inkworm at this time.', style: Theme.of(context).textTheme.labelMedium)),
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
    return IconButton(icon: const Icon(Icons.refresh), onPressed: _checkVersion,);
  }

  Future<void> _checkVersion() async {
    await ref.read(updateProvider.notifier).checkVersion();
  }

  Future<void> _download(WidgetRef ref, String url, String package) async {
    setState( () {
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
