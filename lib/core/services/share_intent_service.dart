import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../features/downloader/data/datasources/youtube_extractor.dart';

/// ShareIntentService — Intercepts system "Share" intents (e.g. from YouTube or browsers)
/// and triggers automatic parsing in the downloader view.
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  /// Initializes listening for shared links while running and on cold start.
  void initialize({required void Function(String url) onUrlReceived}) {
    // 1. Listen for shares while app is in background or foreground
    _intentSub?.cancel();
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        _handleSharedMedia(value, onUrlReceived);
      },
      onError: (_) {},
    );

    // 2. Handle cold start share intent
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value, onUrlReceived);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _handleSharedMedia(
    List<SharedMediaFile> files,
    void Function(String url) onUrlReceived,
  ) {
    if (files.isEmpty) return;

    for (final media in files) {
      final rawText = media.path.trim();
      if (rawText.isEmpty) continue;

      final extractedUrl = extractUrlFromText(rawText);
      if (extractedUrl != null && extractedUrl.isNotEmpty) {
        onUrlReceived(extractedUrl);
        ReceiveSharingIntent.instance.reset();
        break;
      }
    }
  }

  /// Extracts the URL or canonical YouTube URL from arbitrary shared text.
  static String? extractUrlFromText(String text) {
    // If YouTube ID is found anywhere in text, return clean canonical URL
    final ytId = YoutubeExtractor.extractVideoId(text);
    if (ytId != null && ytId.length == 11) {
      return 'https://www.youtube.com/watch?v=$ytId';
    }

    // Otherwise, check for any http/https URL
    final urlRegex = RegExp(r'https?:\/\/[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      return match.group(0);
    }

    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }

    return null;
  }

  void dispose() {
    _intentSub?.cancel();
    _intentSub = null;
  }
}

