import 'dart:typed_data';

class OneDriveResponse {
  final int? statusCode;
  final String? body;
  final String? message;
  final bool isSuccess;
  final Uint8List? bodyBytes;

  OneDriveResponse({
    this.statusCode,
    this.body,
    this.message,
    this.bodyBytes,
    this.isSuccess = false
  });

  @override
  String toString() {
    return "OneDriveResponse("
        "statusCode: $statusCode, "
        "body: $body, "
        "bodyBytes: $bodyBytes, "
        "message: $message, "
        "isSuccess: $isSuccess"
      ")";
  }
}

class OneDriveUserInfo {
  final String? email;
  final String? displayName;
  final int? total;
  final int? used;
  final int? deleted;
  final int? remaining;
  final String? state;

  OneDriveUserInfo({
    this.email,
    this.displayName,
    this.total,
    this.used,
    this.deleted,
    this.remaining,
    this.state
  });

  factory OneDriveUserInfo.fromJson(Map<String, dynamic> json) {
    return OneDriveUserInfo(
      email: json['owner']['user']['email'],
      displayName: json['owner']['user']['displayName'],
      total: json['quota']['total'],
      used: json['quota']['used'],
      deleted: json['quota']['deleted'],
      remaining: json['quota']['remaining'],
      state: json['quota']['state']
    );
  }

  @override
  String toString() {
    return "OneDriveUserInfo("
        "email: $email, "
        "displayName: $displayName, "
        "total: $total, "
        "used: $used, "
        "deleted: $deleted, "
        "remaing: $remaining, "
        "state: $state"
      ")";
  }
}

class OnedriveFileInfo{
  final String id;
  final String name;
  final int size;
  final int createdDateTime;
  final int lastModifiedDateTime;
  final String description;
  final String fileMimeType;

  OnedriveFileInfo({
    required this.id,
    required this.name,
    required this.size,
    required this.createdDateTime,
    required this.lastModifiedDateTime,
    required this.description,
    required this.fileMimeType
  });
}