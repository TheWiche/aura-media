import 'dart:io';
import 'package:flutter/services.dart';
import '../../features/downloader/data/models/download_task.dart';

class InstalledMediaPlayer {
  final String packageName;
  final String appName;
  final Uint8List? iconBytes;

  const InstalledMediaPlayer({
    required this.packageName,
    required this.appName,
    this.iconBytes,
  });
}

/// NativePlatformService — unified bridge to Android-specific capabilities
/// (directory picker, installed media players, MediaScanner, Wi-Fi detection, share modal).
class NativePlatformService {
  NativePlatformService._();
  static final NativePlatformService instance = NativePlatformService._();

  static const MethodChannel _channel = MethodChannel('com.mediasdownload/native');

  void Function(String sharedText)? _onNewShareCallback;
  void Function(String url)? _onNewOpenMainUrlCallback;
  bool _handlerRegistered = false;

  void _ensureMethodCallHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewShareIntent') {
        final text = call.arguments as String?;
        if (text != null && text.trim().isNotEmpty) {
          _onNewShareCallback?.call(text.trim());
        }
      } else if (call.method == 'onOpenMainUrl') {
        final url = call.arguments as String?;
        if (url != null && url.trim().isNotEmpty) {
          _onNewOpenMainUrlCallback?.call(url.trim());
        }
      }
    });
  }

  /// Listen for subsequent share intents delivered to ShareModalActivity via onNewIntent.
  void setNewShareHandler(void Function(String sharedText) callback) {
    _onNewShareCallback = callback;
    _ensureMethodCallHandler();
  }

  /// Listen for URLs forwarded from ShareModalActivity to MainActivity.
  void setOpenMainUrlHandler(void Function(String url) callback) {
    _onNewOpenMainUrlCallback = callback;
    _ensureMethodCallHandler();
  }

  /// Opens Android's native directory picker (`ACTION_OPEN_DOCUMENT_TREE`).
  Future<String?> pickDirectory() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('pickDirectory');
    } catch (_) {
      return null;
    }
  }

  /// Queries installed Android apps capable of playing audio or video files.
  Future<List<InstalledMediaPlayer>> getInstalledMediaPlayers(
    MediaType mediaType,
  ) async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledMediaPlayers',
        {'mediaType': mediaType == MediaType.audio ? 'audio' : 'video'},
      );
      if (raw == null) return const [];

      final list = <InstalledMediaPlayer>[];
      for (final item in raw) {
        if (item is Map) {
          final pkg = item['packageName'] as String? ?? '';
          final name = item['appName'] as String? ?? '';
          final rawBytes = item['iconBytes'];
          final Uint8List? icon =
              (rawBytes is Uint8List && rawBytes.isNotEmpty) ? rawBytes : null;
          if (pkg.isNotEmpty && name.isNotEmpty) {
            list.add(
              InstalledMediaPlayer(
                packageName: pkg,
                appName: name,
                iconBytes: icon,
              ),
            );
          }
        }
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Opens a media file using a specific Android package (via FileProvider) or fails cleanly.
  Future<bool> openMediaFile(
    String path, {
    required String mimeType,
    String? packageName,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openMediaFile', {
        'path': path,
        'mimeType': mimeType,
        'packageName': packageName,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Notifies Android's MediaScanner so new audio/video files appear immediately.
  Future<bool> scanMediaFile(String path, {String? mimeType}) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('scanMediaFile', {
        'path': path,
        'mimeType': mimeType,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the device currently has an active Wi-Fi or Ethernet connection.
  Future<bool> isWifiConnected() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isWifiConnected');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static int? _cachedAndroidSdkInt;

  /// Returns Android `Build.VERSION.SDK_INT` (cached once per isolate; 34 on non-Android).
  Future<int> getAndroidSdkInt() async {
    if (_cachedAndroidSdkInt != null) return _cachedAndroidSdkInt!;
    if (!Platform.isAndroid) {
      _cachedAndroidSdkInt = 34;
      return 34;
    }
    try {
      final sdk = await _channel.invokeMethod<int>('getAndroidSdkInt');
      _cachedAndroidSdkInt = sdk ?? 29;
      return _cachedAndroidSdkInt!;
    } catch (_) {
      _cachedAndroidSdkInt = 29;
      return 29;
    }
  }

  /// Reads versionName+versionCode from Android PackageInfo.
  Future<String> getAppVersion() async {
    if (!Platform.isAndroid) return '1.5.0+12';
    try {
      final version = await _channel.invokeMethod<String>('getAppVersion');
      return (version != null && version.isNotEmpty) ? version : '1.5.0+12';
    } catch (_) {
      return '1.5.0+12';
    }
  }

  /// Attempts to open the specified folder in Android's file explorer.
  Future<bool> openFolder(String path) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openFolder', {'path': path});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the initial shared text received by ShareModalActivity.
  Future<String?> getSharePayload() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getSharePayload');
    } catch (_) {
      return null;
    }
  }

  /// Closes ShareModalActivity and returns cleanly to the source app.
  Future<void> closeShareModal() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('closeShareModal');
    } catch (_) {}
  }

  /// Opens MainActivity, optionally passing a URL to pre-fill.
  Future<void> openMainApp({String? url}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openMainApp', {'url': url});
    } catch (_) {}
  }

  /// Retrieves any pending URL passed when launching MainActivity from ShareModalActivity.
  Future<String?> getMainOpenUrl() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getMainOpenUrl');
    } catch (_) {
      return null;
    }
  }
}
