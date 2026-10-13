import 'package:http/http.dart' as http;
import '../models/download_task.dart';
import '../models/media_metadata.dart';

class GenericStreamResult {
  final String streamUrl;
  final String title;
  final String extension;
  final int totalBytes;

  GenericStreamResult({
    required this.streamUrl,
    required this.title,
    required this.extension,
    required this.totalBytes,
  });
}

/// GenericExtractor — Handles direct web media downloads (e.g. direct mp4, mp3, m4a links).
/// 100% local, no third-party APIs or proxies.
class GenericExtractor {
  final http.Client _client;

  GenericExtractor({http.Client? client}) : _client = client ?? http.Client();

  /// Detect platform from URL
  static String detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('tiktok.com')) return 'TikTok';
    if (lower.contains('instagram.com')) return 'Instagram';
    if (lower.contains('twitter.com') || lower.contains('x.com')) return 'Twitter / X';
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) return 'Facebook';
    if (lower.contains('vimeo.com')) return 'Vimeo';
    if (lower.contains('reddit.com')) return 'Reddit';
    return 'Web Directo';
  }

  /// Fetch generic metadata via local HTTP HEAD request
  Future<MediaMetadata> fetchMetadata(String url) async {
    final platform = detectPlatform(url);
    final uri = Uri.tryParse(url.trim());
    if (uri == null) throw Exception('URL inválida');

    // For direct media URLs (ends with .mp4, .mp3, etc.)
    final path = uri.path.toLowerCase();
    if (path.endsWith('.mp4') ||
        path.endsWith('.mp3') ||
        path.endsWith('.m4a') ||
        path.endsWith('.mkv')) {
      try {
        await _client.head(uri);
      } catch (_) {}
      final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media_file';
      return MediaMetadata(
        url: url.trim(),
        title: filename,
        author: platform,
        platform: platform,
      );
    }

    return MediaMetadata(
      url: url.trim(),
      title: '$platform Media',
      author: platform,
      platform: platform,
    );
  }

  /// Resolve stream for direct links locally
  Future<GenericStreamResult> resolveStream({
    required String url,
    required MediaType mediaType,
  }) async {
    final uri = Uri.parse(url.trim());
    final path = uri.path.toLowerCase();

    int len = 0;
    try {
      final head = await _client.head(uri);
      len = int.tryParse(head.headers['content-length'] ?? '0') ?? 0;
    } catch (_) {}

    final ext = path.endsWith('.mp3')
        ? 'mp3'
        : (path.endsWith('.m4a') ? 'm4a' : 'mp4');

    final filename = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'download_${DateTime.now().millisecondsSinceEpoch}';

    return GenericStreamResult(
      streamUrl: url.trim(),
      title: filename,
      extension: ext,
      totalBytes: len,
    );
  }

  void close() {
    _client.close();
  }
}
