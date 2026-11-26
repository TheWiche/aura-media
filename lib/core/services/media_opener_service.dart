import 'dart:io';
import 'package:open_filex/open_filex.dart';
import '../../features/downloader/data/models/download_task.dart';
import 'native_platform_service.dart';
import 'settings_service.dart';

/// Opens downloaded audio/video files using the user's preferred media player
/// (or falls back to the system default / OpenFilex).
class MediaOpenerService {
  MediaOpenerService._();

  static Future<OpenResult> openFile(
    String path, {
    MediaType? mediaType,
  }) async {
    final lower = path.toLowerCase();
    final inferredType = mediaType ??
        (_isAudioExtension(lower) ? MediaType.audio : MediaType.video);

    if (Platform.isAndroid) {
      await SettingsService.instance.initialize();
      final preferredPkg = inferredType == MediaType.audio
          ? SettingsService.instance.getAudioPlayerPackage()
          : SettingsService.instance.getVideoPlayerPackage();

      if (preferredPkg != null && preferredPkg.isNotEmpty) {
        final mime = _mimeTypeFor(lower, inferredType);
        final opened = await NativePlatformService.instance.openMediaFile(
          path,
          mimeType: mime,
          packageName: preferredPkg,
        );
        if (opened) {
          return OpenResult(type: ResultType.done);
        }
      }
    }

    return OpenFilex.open(path);
  }

  static bool _isAudioExtension(String lowerPath) {
    return lowerPath.endsWith('.mp3') ||
        lowerPath.endsWith('.m4a') ||
        lowerPath.endsWith('.aac') ||
        lowerPath.endsWith('.ogg') ||
        lowerPath.endsWith('.wav') ||
        lowerPath.endsWith('.flac') ||
        lowerPath.endsWith('.opus');
  }

  static String _mimeTypeFor(String lowerPath, MediaType type) {
    if (lowerPath.endsWith('.mp3')) return 'audio/mpeg';
    if (lowerPath.endsWith('.m4a')) return 'audio/mp4';
    if (lowerPath.endsWith('.aac')) return 'audio/aac';
    if (lowerPath.endsWith('.ogg') || lowerPath.endsWith('.opus')) {
      return 'audio/ogg';
    }
    if (lowerPath.endsWith('.wav')) return 'audio/wav';
    if (lowerPath.endsWith('.flac')) return 'audio/flac';
    if (lowerPath.endsWith('.mp4')) return 'video/mp4';
    if (lowerPath.endsWith('.mkv')) return 'video/x-matroska';
    if (lowerPath.endsWith('.webm')) return 'video/webm';
    return type == MediaType.audio ? 'audio/*' : 'video/*';
  }
}
