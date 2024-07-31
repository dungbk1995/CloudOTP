import 'dart:typed_data';

abstract class CloudService {
  Future<void> init();

  Future<dynamic> listFiles();

  Future<void> uploadFile(String fileName, Uint8List fileData);

  Future<Uint8List> downloadFile(String path);

  Future<void> deleteFile(String path);

  Future<void> authenticate();

  Future<void> signOut();
}
