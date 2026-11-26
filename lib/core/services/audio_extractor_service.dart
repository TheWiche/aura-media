import 'dart:io';
import 'package:flutter/services.dart';

class AudioExtractorService {
  static const MethodChannel _channel =
      MethodChannel('com.mediasdownload/audio_extractor');

  /// Extracts/remuxes the audio track from [inputPath] into a clean seekable container at [outputPath].
  /// Returns `true` if extraction succeeded, `false` otherwise.
  static Future<bool> extractAudio({
    required String inputPath,
    required String outputPath,
  }) async {
    if (!Platform.isAndroid) {
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

  /// Combines separate adaptive [videoPath] and [audioPath] streams natively on Android
  /// using `MediaMuxer` (`mp4` or `webm`) with zero re-encoding.
  static Future<bool> muxVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    String containerFormat = 'mp4',
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('muxVideoAndAudio', {
        'videoPath': videoPath,
        'audioPath': audioPath,
        'outputPath': outputPath,
        'containerFormat': containerFormat,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
