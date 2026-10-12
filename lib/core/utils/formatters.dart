import 'dart:math';

class Formatters {
  /// Format raw bytes into human readable String (e.g. 15.4 MB, 1.2 GB)
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = i.clamp(0, suffixes.length - 1);
    final size = bytes / pow(1024, clampedIndex);
    return '${size.toStringAsFixed(decimals)} ${suffixes[clampedIndex]}';
  }

  /// Format download speed in bytes/second into human readable String
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 KB/s';
    if (bytesPerSecond < 1024 * 1024) {
      final kb = bytesPerSecond / 1024;
      return '${kb.toStringAsFixed(1)} KB/s';
    } else {
      final mb = bytesPerSecond / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB/s';
    }
  }

  /// Format Duration into mm:ss or hh:mm:ss
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Calculate and format Estimated Time of Arrival (ETA)
  static String formatETA(int remainingBytes, double bytesPerSecond) {
    if (bytesPerSecond <= 0 || remainingBytes <= 0) return '--:--';
    final secondsRemaining = (remainingBytes / bytesPerSecond).round();
    if (secondsRemaining > 3600 * 24) return '> 24h';
    return formatDuration(Duration(seconds: secondsRemaining));
  }

  /// Sanitize file name for filesystem safety
  static String sanitizeFileName(String fileName) {
    // Remove invalid filename characters across Windows, Android and iOS
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    var sanitized = fileName.replaceAll(invalidChars, '_').trim();
    if (sanitized.isEmpty) {
      sanitized = 'media_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (sanitized.length > 120) {
      sanitized = sanitized.substring(0, 120);
    }
    return sanitized;
  }
}

