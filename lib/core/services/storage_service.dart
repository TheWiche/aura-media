import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  Directory? _cachedDownloadDir;

  /// Get the target directory for downloaded files.
  /// On Android: tries public /storage/emulated/0/Download/MediasDownload,
  /// with fallback to external or app documents directory.
  /// On iOS: app documents directory with subfolder MediasDownload.
  Future<Directory> getDownloadDirectory() async {
    if (_cachedDownloadDir != null && await _cachedDownloadDir!.exists()) {
      return _cachedDownloadDir!;
    }

    Directory baseDir;
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        baseDir = Directory('${publicDownload.path}/${AppConstants.appDownloadFolderName}');
      } else {
        final extDir = await getExternalStorageDirectory();
        baseDir = Directory('${extDir?.path ?? (await getApplicationDocumentsDirectory()).path}/${AppConstants.appDownloadFolderName}');
      }
    } else {
      // iOS / other platforms
      final docs = await getApplicationDocumentsDirectory();
      baseDir = Directory('${docs.path}/${AppConstants.appDownloadFolderName}');
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    _cachedDownloadDir = baseDir;
    return baseDir;
  }

  /// Build full target path for a new file
  Future<String> getTargetPath(String fileName) async {
    final dir = await getDownloadDirectory();
    return '${dir.path}/$fileName';
  }

  /// Delete a physical file from disk
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  /// List all downloaded media files in directory
  Future<List<FileSystemEntity>> listDownloadedFiles() async {
    final dir = await getDownloadDirectory();
    if (await dir.exists()) {
      return dir.listSync().whereType<File>().toList();
    }
    return [];
  }
}

