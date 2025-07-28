/*
 * Copyright (c) 2024 Robert-Stackflow.
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.
 * If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:ffi';
import 'dart:io';

import 'package:cloudotp/Models/github_response.dart';
import 'package:cloudotp/Utils/app_provider.dart';
import 'package:cloudotp/Utils/constant.dart';
import 'package:cloudotp/Utils/hive_util.dart';
import 'package:cloudotp/Utils/responsive_util.dart';
import 'package:cloudotp/Utils/uri_util.dart';
import 'package:cloudotp/Utils/utils.dart';
import 'package:cloudotp/Utils/website_util.dart';
import 'package:cloudotp/Widgets/Dialog/dialog_builder.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saf/saf.dart';
import 'package:win32/win32.dart';

import '../../Utils/ilogger.dart';
import '../Widgets/Dialog/custom_dialog.dart';
import '../generated/l10n.dart';
import 'itoast.dart';
import 'notification_util.dart';

enum WindowsVersion { installed, portable }

class FileUtil {
  static Future<String?> getDirectoryBySAF() async {
    Saf saf = Saf("/Documents");
    await Saf.releasePersistedPermissions();
    bool? isGranted = await saf.getDirectoryPermission(
      grantWritePermission: true,
      isDynamic: true,
    );
    if (isGranted != null && isGranted) {
      List<String>? directories = await Saf.getPersistedPermissionDirectories();
      if (directories != null && directories.isNotEmpty) {
        return "/storage/emulated/0/${directories.first}";
      }
      return null;
    }
    return null;
  }

  static Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    FilePickerResult? result;
    try {
      appProvider.preventLock = true;
      result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        lockParentWindow: lockParentWindow,
        onFileLoading: onFileLoading,
        allowCompression: allowCompression,
        compressionQuality: compressionQuality,
        allowMultiple: allowMultiple,
        withData: withData,
        withReadStream: withReadStream,
        readSequential: readSequential,
      );
    } catch (e, t) {
      ILogger.error("CloudOTP", "Failed to pick files", e, t);
      IToast.showTop(S.current.pleaseGrantFilePermission);
    } finally {
      appProvider.preventLock = false;
    }
    return result;
  }

  static Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    String? result;
    try {
      appProvider.preventLock = true;
      result = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        lockParentWindow: lockParentWindow,
        bytes: bytes,
        fileName: fileName,
      );
    } catch (e, t) {
      ILogger.error("CloudOTP", "Failed to save file", e, t);
      IToast.showTop(S.current.pleaseGrantFilePermission);
    } finally {
      appProvider.preventLock = false;
    }
    return result;
  }

  static Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    bool lockParentWindow = false,
  }) async {
    String? result;
    try {
      appProvider.preventLock = true;
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 30) {
          return await getDirectoryBySAF();
        }
      }
      result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        lockParentWindow: lockParentWindow,
      );
    } catch (e, t) {
      ILogger.error("CloudOTP", "Failed to get directory path", e, t);
      IToast.showTop(S.current.pleaseGrantFilePermission);
    } finally {
      appProvider.preventLock = false;
    }
    return result;
  }

  static exportLogs({
    bool showLoading = true,
  }) async {
    if (!(await FileOutput.haveLogs())) {
      IToast.showTop(S.current.noLog);
      return;
    }
    if (ResponsiveUtil.isDesktop()) {
      String? filePath = await FileUtil.saveFile(
        dialogTitle: S.current.exportLog,
        fileName:
            "CloudOTP-Logs-${Utils.getFormattedDate(DateTime.now())}-${ResponsiveUtil.deviceName}.zip",
        type: FileType.custom,
        allowedExtensions: ['zip'],
        lockParentWindow: true,
      );
      if (filePath != null) {
        if (showLoading) {
          CustomLoadingDialog.showLoading(title: S.current.exporting);
        }
        try {
          Uint8List? data = await FileOutput.getArchiveData();
          if (data != null) {
            File file = File(filePath);
            await file.writeAsBytes(data);
            IToast.showTop(S.current.exportSuccess);
          } else {
            IToast.showTop(S.current.exportFailed);
          }
        } catch (e, t) {
          ILogger.error("CloudOTP", "Failed to zip logs", e, t);
          IToast.showTop(S.current.exportFailed);
        } finally {
          if (showLoading) {
            CustomLoadingDialog.dismissLoading();
          }
        }
      }
    } else {
      if (showLoading) {
        CustomLoadingDialog.showLoading(title: S.current.exporting);
      }
      try {
        Uint8List? data = await FileOutput.getArchiveData();
        if (data == null) {
          IToast.showTop(S.current.exportFailed);
          return;
        }
        String? filePath = await FileUtil.saveFile(
          dialogTitle: S.current.exportLog,
          fileName:
              "CloudOTP-Logs-${Utils.getFormattedDate(DateTime.now())}-${ResponsiveUtil.deviceName}.zip",
          type: FileType.custom,
          allowedExtensions: ['zip'],
          lockParentWindow: true,
          bytes: data,
        );
        if (filePath != null) {
          IToast.showTop(S.current.exportSuccess);
        }
      } catch (e, t) {
        ILogger.error("CloudOTP", "Failed to zip logs", e, t);
        IToast.showTop(S.current.exportFailed);
      } finally {
        if (showLoading) {
          CustomLoadingDialog.dismissLoading();
        }
      }
    }
  }

  static Future<bool> isDirectoryEmpty(Directory directory) async {
    if (!await directory.exists()) {
      return true;
    }
    return directory.listSync().isEmpty;
  }

  static Future<void> createBakDir(
    Directory sourceDir, [
    Directory? destDir,
  ]) async {
    Directory directory = destDir ?? Directory("${sourceDir.path}-bak");
    if (await directory.exists()) {
      return;
    } else {
      await directory.create(recursive: true);
    }
    await copyDirectoryTo(sourceDir, directory);
  }

  static Future<void> copyDirectoryTo(
      Directory oldDir, Directory newDir) async {
    ILogger.info(
        "CloudOTP", "Copy directory from ${oldDir.path} to ${newDir.path}");
    if (!await oldDir.exists()) {
      return;
    }
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }
    List<FileSystemEntity> files = oldDir.listSync();
    if (files.isNotEmpty) {
      for (var file in files) {
        if (file is File) {
          String fileName = FileUtil.getFileNameWithExtension(file.path);
          await file.copy(join(newDir.path, fileName));
          ILogger.info(
              "CloudOTP", "Copy file from ${file.path} to ${newDir.path}");
        } else if (file is Directory) {
          String dirName = FileUtil.getFileNameWithExtension(file.path);
          Directory newSubDir = Directory(join(newDir.path, dirName));
          await copyDirectoryTo(file, newSubDir);
        }
      }
    }
  }

  static Future<void> deleteDirectory(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    List<FileSystemEntity> files = directory.listSync();
    if (files.isNotEmpty) {
      for (var file in files) {
        if (file is File) {
          await file.delete();
        } else if (file is Directory) {
          await deleteDirectory(file);
        }
      }
    }
    await directory.delete();
  }

  static Future<void> migrationDataToSupportDirectory() async {
    try {
      Hive.defaultDirectory = await FileUtil.getHiveDir();
      bool haveMigratedToSupportDirectoryFromHive = HiveUtil.getBool(
          HiveUtil.haveMigratedToSupportDirectoryKey,
          defaultValue: false);
      if (haveMigratedToSupportDirectoryFromHive) {
        ILogger.info("CloudOTP", "Have migrated data to support directory");
        return;
      }
      Hive.closeAllBoxes();
    } catch (e, t) {
      ILogger.error("CloudOTP", "Failed to close all hive boxes", e, t);
    }
    Directory oldDir = Directory(await getOldApplicationDir());
    Directory newDir = Directory(await getApplicationDir());
    try {
      if (oldDir.path == newDir.path || await isDirectoryEmpty(oldDir)) {
        return;
      }
      await createBakDir(oldDir, Directory("${newDir.path}-old-bak"));
      bool isNewDirEmpty = await isDirectoryEmpty(newDir);
      if (!isNewDirEmpty) {
        await createBakDir(newDir);
      }
      ILogger.info("CloudOTP",
          "Start to migrate data from old application directory $oldDir to new application directory $newDir");
      await copyDirectoryTo(oldDir, newDir);
      haveMigratedToSupportDirectory = true;
    } catch (e, t) {
      ILogger.error("CloudOTP",
          "Failed to migrate data from old application directory", e, t);
    }
    try {
      await deleteDirectory(oldDir);
    } catch (e, t) {
      ILogger.error(
          "CloudOTP", "Failed to delete old application directory", e, t);
    }
    ILogger.info("CloudOTP",
        "Finish to migrate data from old application directory $oldDir to new application directory $newDir");
    await Future.delayed(const Duration(milliseconds: 200));
  }

  static void showMigrationDialog(BuildContext context) {
    //TODO
  }

  static Future<String> getApplicationDir() async {
    //   return await getOldApplicationDir();
    var path = (await getApplicationSupportDirectory()).path;
    if (kDebugMode) {
      path += "-Debug";
    }
    Directory directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return path;
  }

  static Future<String> getOldApplicationDir() async {
    final dir = await getApplicationDocumentsDirectory();
    var appName = (await PackageInfo.fromPlatform()).appName;
    if (kDebugMode) {
      appName += "-Debug";
    }
    String path = join(dir.path, appName);
    Directory directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return path;
  }

  static Future<String> getFontDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Fonts"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getBackupDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Backup"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getScreenshotDir() async {
    Directory directory =
        Directory(join(await getApplicationDir(), "Screenshots"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getLogDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Logs"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getHiveDir() async {
    Directory directory = Directory(join(await getApplicationDir(), "Hive"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<String> getDatabaseDir() async {
    Directory directory =
        Directory(join(await getApplicationDir(), "Database"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static String getFileNameWithExtension(String imageUrl) {
    return Uri.parse(imageUrl).pathSegments.last;
  }

  static String getFileExtension(String imageUrl) {
    return getFileNameWithExtension(imageUrl).split('.').last;
  }

  static String getFileName(String imageUrl) {
    return getFileNameWithExtension(imageUrl).split('.').first;
  }

  static Future<void> downloadAndUpdate(
    BuildContext context,
    String apkUrl,
    String htmlUrl, {
    String? version,
    Function(double)? onReceiveProgress,
  }) async {
    bool enableNotification = await Permission.notification.isGranted;
    if (Utils.isNotEmpty(apkUrl)) {
      double progressValue = 0.0;
      var appDocDir = await getTemporaryDirectory();
      String savePath =
          "${appDocDir.path}/${FileUtil.getFileNameWithExtension(apkUrl)}";
      try {
        await Dio().download(
          apkUrl,
          savePath,
          onReceiveProgress: (count, total) {
            final value = count / total;
            if (progressValue != value) {
              if (progressValue < 1.0) {
                progressValue = count / total;
              } else {
                progressValue = 0.0;
              }
              NotificationUtil.sendProgressNotification(
                0,
                (progressValue * 100).toInt(),
                title: S.current.downloadingNewVersionPackage,
                payload: version ?? "",
              );
              onReceiveProgress?.call(progressValue);
            }
          },
        ).then((response) async {
          if (response.statusCode == 200) {
            if (enableNotification) {
              NotificationUtil.closeNotification(0);
              NotificationUtil.sendInfoNotification(
                1,
                S.current.downloadComplete,
                S.current.downloadSuccessClickToInstall,
                payload: savePath,
              );
            } else {
              // DialogBuilder.showConfirmDialog(context,
              //     title: S.current.downloadComplete,
              //     message: S.current.downloadSuccessClickToInstall,
              //     cancelButtonText: S.current.updateLater,
              //     confirmButtonText: S.current.immediatelyInstall,
              //     onTapConfirm: () async {
              //   await InstallPlugin.install(savePath);
              // });
            }
          } else {
            UriUtil.openExternal(htmlUrl);
          }
        });
      } catch (e, t) {
        ILogger.error("CloudOTP", "Failed to download apk", e, t);
        DialogBuilder.showConfirmDialog(
          context,
          title: S.current.downloadFailedAndRetry,
          message: S.current.downloadFailedAndRetryTip,
          confirmButtonText: S.current.goToBrowserUpdate,
          cancelButtonText: S.current.updateLater,
          onTapConfirm: () {
            UriUtil.openExternal(WebsiteUtil.getDownloadsWebsite(context));
          },
        );
        NotificationUtil.closeNotification(0);
        NotificationUtil.sendInfoNotification(
          2,
          S.current.downloadFailedAndRetry,
          S.current.downloadFailedAndRetryTip,
        );
      }
    } else {
      UriUtil.openExternal(htmlUrl);
    }
  }

  static Future<File> copyAndRenameFile(
    File file,
    String newFileName, {
    String? dir,
  }) async {
    dir ??= file.parent.path;
    String newPath = '$dir/$newFileName';
    File copiedFile = await file.copy(newPath);
    await copiedFile.rename(newPath);
    return copiedFile;
  }

  static Future<ReleaseAsset> getAndroidAsset(
      String latestVersion, ReleaseItem item) async {
    ReleaseAsset? resAsset;
    List<ReleaseAsset> assets = item.assets.where((element) {
      return ["application/vnd.android.package-archive", "raw"]
              .contains(element.contentType) &&
          element.name.endsWith(".apk");
    }).toList();
    ReleaseAsset generalAsset = assets.firstWhere((element) {
      return [
        'CloudOTP-$latestVersion.apk',
        'CloudOTP-$latestVersion-android-universal.apk'
      ].contains(element.name);
    }, orElse: () => assets.first);
    try {
      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      List<String> supportedAbis =
          androidInfo.supportedAbis.map((e) => e.toLowerCase()).toList();
      for (var asset in assets) {
        String abi =
            asset.name.split("CloudOTP-$latestVersion-").last.split(".").first;
        for (var supportedAbi in supportedAbis) {
          if (abi.toLowerCase().contains(supportedAbi)) {
            resAsset = asset;
            break;
          }
        }
      }
    } finally {}
    resAsset ??= generalAsset;
    resAsset.pkgsDownloadUrl =
        Utils.getDownloadUrl(latestVersion, resAsset.name);
    return resAsset;
  }

  static WindowsVersion checkWindowsVersion() {
    WindowsVersion tmp = WindowsVersion.portable;

    final key = calloc<IntPtr>();
    final installPathPtr = calloc<Uint16>(260);
    final dataSize = calloc<Uint32>();
    dataSize.value = 260 * 2;

    final result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, TEXT(windowsKeyPath), 0,
        REG_SAM_FLAGS.KEY_READ, key);
    if (result == WIN32_ERROR.ERROR_SUCCESS) {
      final queryResult = RegQueryValueEx(key.value, TEXT('InstallPath'),
          nullptr, nullptr, installPathPtr.cast(), dataSize);

      if (queryResult == WIN32_ERROR.ERROR_SUCCESS) {
        final currentPath = Platform.resolvedExecutable;
        final installPath =
            "${installPathPtr.cast<Utf16>().toDartString()}\\CloudOTP.exe";
        ILogger.info("CloudOTP",
            "Get install path: $installPath and current path: $currentPath");
        tmp = installPath == currentPath
            ? WindowsVersion.installed
            : WindowsVersion.portable;
      } else {
        tmp = WindowsVersion.portable;
      }
    }
    RegCloseKey(key.value);
    calloc.free(key);
    calloc.free(installPathPtr);
    calloc.free(dataSize);
    return tmp;
  }

  static ReleaseAsset getWindowsAsset(String latestVersion, ReleaseItem item) {
    final windowsVersion = FileUtil.checkWindowsVersion();
    if (windowsVersion == WindowsVersion.installed) {
      return getWindowsInstallerAsset(latestVersion, item);
    } else {
      return getWindowsPortableAsset(latestVersion, item);
    }
  }

  static ReleaseAsset getWindowsPortableAsset(
      String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return ["application/zip", "application/x-zip-compressed", "raw"]
              .contains(element.contentType) &&
          element.name.contains("windows") &&
          element.name.endsWith(".zip");
    });
    asset.pkgsDownloadUrl = Utils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }

  static ReleaseAsset getWindowsInstallerAsset(
      String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return ["application/x-msdownload", "application/x-msdos-program", "raw"]
              .contains(element.contentType) &&
          element.name.contains("windows") &&
          element.name.endsWith(".exe");
    });
    asset.pkgsDownloadUrl = Utils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }

  static ReleaseAsset getLinuxDebianAsset(
      String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return [
            "application/vnd.debian.binary-package",
            "application/x-debian-package",
            "raw"
          ].contains(element.contentType) &&
          element.name.endsWith(".deb");
    });
    asset.pkgsDownloadUrl = Utils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }

  static ReleaseAsset getLinuxTarGzAsset(
      String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return [
            "application/gzip",
            "application/x-gzip",
            "application/x-tar",
            "raw"
          ].contains(element.contentType) &&
          element.name.endsWith(".tar.gz");
    });
    asset.pkgsDownloadUrl = Utils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }

  static ReleaseAsset getIosIpaAsset(String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return ["application/octet-stream", "raw"]
              .contains(element.contentType) &&
          element.name.endsWith(".ipa");
    });
    asset.pkgsDownloadUrl = Utils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }

  static ReleaseAsset getMacosDmgAsset(String latestVersion, ReleaseItem item) {
    var asset = item.assets.firstWhere((element) {
      return ["application/x-apple-diskimage", "raw"]
              .contains(element.contentType) &&
          element.name.endsWith(".dmg");
    });
    asset.pkgsDownloadUrl = Utils.getDownloadUrl(latestVersion, asset.name);
    return asset;
  }
}
