import 'dart:io';
import 'package:flutter/services.dart';

/// NativePlatformService — unified bridge to Android-specific capabilities
/// (directory picker, MediaScanner, Wi-Fi detection, share modal lifecycle, app version).
class NativePlatformService {
  NativePlatformService._();
  static final NativePlatformService instance = NativePlatformService._();

  static const MethodChannel _channel = MethodChannel('com.mediasdownload/native');

  void Function(String sharedText)? _onNewShareCallback;
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

  void Function(String url)? _onNewOpenMainUrlCallback;

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

  /// Opens Android's native directory picker (`ACTION_OPEN_DOCUMENT_TREE`)
  /// and resolves it to a writable filesystem path when possible.
  Future<String?> pickDirectory() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('pickDirectory');
    } catch (_) {
      return null;
    }
  }

  /// Notifies Android's MediaScanner so new audio/video files appear immediately
  /// in music players and gallery apps.
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

  /// Returns true if the device currently has an active Wi-Fi (or Ethernet) connection.
  /// Returns true on non-Android platforms or if plugin unavailable.
  Future<bool> isWifiConnected() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isWifiConnected');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Reads versionName+versionCode from Android PackageInfo.
  Future<String> getAppVersion() async {
    if (!Platform.isAndroid) return '1.3.0+10';
    try {
      final version = await _channel.invokeMethod<String>('getAppVersion');
      return (version != null && version.isNotEmpty) ? version : '1.3.0+10';
    } catch (_) {
      return '1.3.0+10';
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

  /// Closes ShareModalActivity and returns the user cleanly to the source app (e.g. YouTube).
  Future<void> closeShareModal() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('closeShareModal');
    } catch (_) {}
  }

  /// Opens MainActivity (full app), optionally passing a URL to pre-fill.
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
