import 'dart:io';
import 'package:flutter/services.dart';

class AudioExtractorService {
  static const MethodChannel _channel =
      MethodChannel('com.mediasdownload/audio_extractor');

  /// Extracts the audio track from [inputPath] (an MP4 file) and writes it to [outputPath].
  /// Returns `true` if extraction succeeded, `false` otherwise.
  static Future<bool> extractAudio({
    required String inputPath,
    required String outputPath,
  }) async {
    if (!Platform.isAndroid) {
      // Fallback on non-Android platforms: simply rename
      final inputFile = File(inputPath);
      if (await inputFile.exists()) {
        await inputFile.rename(outputPath);
        return true;
      }
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('extractAudio', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
