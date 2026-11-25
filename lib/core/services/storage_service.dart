import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../../features/downloader/data/models/download_task.dart';
import 'settings_service.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  /// Computes the default download folder for [mediaType] without mutating custom settings.
  Future<Directory> getDefaultDownloadDirectory(MediaType mediaType) async {
    final subfolder = mediaType == MediaType.audio
        ? AppConstants.defaultAudioSubfolder
        : AppConstants.defaultVideoSubfolder;

    Directory baseDir;
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        baseDir = Directory(
          '${publicDownload.path}/${AppConstants.appDownloadFolderName}/$subfolder',
        );
      } else {
        String root;
        try {
          final extDir = await getExternalStorageDirectory();
          root = extDir?.path ?? (await getApplicationDocumentsDirectory()).path;
        } catch (_) {
          root = Directory.systemTemp.path;
        }
        baseDir = Directory(
          '$root/${AppConstants.appDownloadFolderName}/$subfolder',
        );
      }
    } else {
      String root;
      try {
        root = (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        root = Directory.systemTemp.path;
      }
      baseDir = Directory(
        '$root/${AppConstants.appDownloadFolderName}/$subfolder',
      );
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// Gets the active download directory for [mediaType], respecting custom folders
  /// configured in [SettingsService]. Falls back to default if custom path isn't accessible.
  Future<Directory> getDownloadDirectory([
    MediaType mediaType = MediaType.video,
  ]) async {
    final customPath = mediaType == MediaType.audio
        ? SettingsService.instance.getAudioDownloadPath()
        : SettingsService.instance.getVideoDownloadPath();

    if (customPath != null && customPath.isNotEmpty) {
      try {
        final customDir = Directory(customPath);
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        return customDir;
      } catch (_) {
        // Fallback to default folder if custom path cannot be created
      }
    }

    return getDefaultDownloadDirectory(mediaType);
  }

  /// Tests whether [directoryPath] can be created and written to on disk.
  Future<bool> isDirectoryWritable(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File(
        '${dir.path}/.aura_write_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      await probe.writeAsString('ok', flush: true);
      if (await probe.exists()) {
        await probe.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Builds a temporary path inside the OS temp/cache directory so incomplete `.tmp`
  /// downloads never clutter the user's Music/Video folders.
  Future<String> getTempDownloadPath(String taskId) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final workDir = Directory('${tempDir.path}/aura_tmp');
    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }
    return '${workDir.path}/$taskId.tmp';
  }

  /// Builds the final target path for a file in the appropriate [mediaType] folder,
  /// applying [DuplicateFilePolicy] (`rename` appends `(1)`, `(2)`, etc.).
  Future<String> getTargetPath(
    String fileName, {
    MediaType mediaType = MediaType.video,
    DuplicateFilePolicy? duplicatePolicy,
  }) async {
    final dir = await getDownloadDirectory(mediaType);
    final policy =
        duplicatePolicy ?? SettingsService.instance.getDuplicatePolicy();

    final candidate = '${dir.path}/$fileName';
    if (policy == DuplicateFilePolicy.overwrite ||
        !await File(candidate).exists()) {
      return candidate;
    }

    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';

    var counter = 1;
    while (counter < 1000) {
      final numbered = '${dir.path}/$baseName ($counter)$extension';
      if (!await File(numbered).exists()) {
        return numbered;
      }
      counter++;
    }
    return '${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}$extension';
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

  /// List all downloaded media files across both audio and video directories
  Future<List<FileSystemEntity>> listDownloadedFiles() async {
    final files = <FileSystemEntity>[];
    final seen = <String>{};

    for (final type in [MediaType.audio, MediaType.video]) {
      final dir = await getDownloadDirectory(type);
      if (await dir.exists()) {
        for (final entity in dir.listSync().whereType<File>()) {
          if (seen.add(entity.path)) {
            files.add(entity);
          }
        }
      }
    }
    return files;
  }
}
