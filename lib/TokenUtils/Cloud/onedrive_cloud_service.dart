import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_onedrive/flutter_onedrive.dart';
import 'package:flutter_onedrive/onedrive_response.dart';
import 'package:path/path.dart';

import '../../Models/cloud_service_config.dart';
import '../../generated/l10n.dart';
import 'cloud_service.dart';

class OneDriveCloudService extends CloudService {
  static const String _redirectUrl = 'cloudotp://auth/onedrive/callback';
  static const String _clientID = '3b953ca4-3dd4-4148-a80b-b1ac8c39fd97';
  static const String _onedrivePath = '/CloudOTP';
  final CloudServiceConfig _config;
  late OneDrive onedrive;
  late BuildContext context;
  Function(CloudServiceConfig)? onConfigChanged;

  OneDriveCloudService(
    this.context,
    this._config, {
    this.onConfigChanged,
  }) {
    init();
  }

  @override
  Future<void> init() async {
    onedrive = OneDrive(redirectURL: _redirectUrl, clientID: _clientID);
  }

  @override
  Future<CloudServiceStatus> authenticate() async {
    bool isAuthorized = await onedrive.isConnected();
    if (!isAuthorized) {
      isAuthorized = await onedrive.connect(
        context,
        windowName: S.current.cloudTypeOneDriveAuthenticateWindowName,
      );
      if (isAuthorized) {
        await fetchInfo();
        return CloudServiceStatus.success;
      } else {
        return CloudServiceStatus.unauthorized;
      }
    } else {
      return CloudServiceStatus.success;
    }
  }

  Future<OneDriveUserInfo> fetchInfo() async {
    OneDriveResponse response = await onedrive.getInfo();
    OneDriveUserInfo info =
        OneDriveUserInfo.fromJson(jsonDecode(response.body ?? "{}"));
    _config.account = info.email;
    _config.remainingSize = info.remaining ?? 0;
    _config.totalSize = info.total ?? 0;
    _config.usedSize = info.used ?? 0;
    onConfigChanged?.call(_config);
    return info;
  }

  @override
  Future<bool> isConnected() async {
    bool connected = await onedrive.isConnected();
    if (connected) {
      await fetchInfo();
    }
    return connected;
  }

  @override
  Future<void> deleteFile(String path) async {
    print('deleteFile');
  }

  @override
  Future<void> deleteOldBackup(int maxCount) async {
    print('deleteOldBackup');
  }

  @override
  Future<Uint8List> downloadFile(
    String path, {
    Function(int p1, int p2)? onProgress,
  }) async {
    print('downloadFile');
    return Uint8List(0);
  }

  @override
  Future<int> getBackupsCount() async {
    print("getBackupsCount");
    return 0;
  }

  @override
  Future listBackups() async {
    print("listBackups");
  }

  @override
  Future listFiles() async {
    await onedrive.list(_onedrivePath);
  }

  @override
  Future<void> signOut() async {
    await onedrive.disconnect();
  }

  @override
  Future<bool> uploadFile(
    String fileName,
    Uint8List fileData, {
    Function(int p1, int p2)? onProgress,
  }) async {
    OneDriveResponse response = await onedrive.push(
      fileData,
      join(_onedrivePath, fileName),
    );
    return response.isSuccess;
  }
}
