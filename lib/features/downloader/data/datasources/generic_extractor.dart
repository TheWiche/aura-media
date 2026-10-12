import 'dart:convert';
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

class GenericExtractor {
  final http.Client _client;
  // Cobalt instance URL (configurable)
  final String cobaltApiUrl;

  GenericExtractor({
    http.Client? client,
    this.cobaltApiUrl = 'https://api.cobalt.tools',
  }) : _client = client ?? http.Client();

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

  /// Fetch generic metadata via HEAD request or Cobalt API
  Future<MediaMetadata> fetchMetadata(String url) async {
    final platform = detectPlatform(url);
    final uri = Uri.tryParse(url.trim());
    if (uri == null) throw Exception('URL inválida');

    // If direct media URL (ends with .mp4, .mp3, etc.)
    final path = uri.path.toLowerCase();
    if (path.endsWith('.mp4') || path.endsWith('.mp3') || path.endsWith('.m4a') || path.endsWith('.mkv')) {
      await _client.head(uri);
      final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media_file';
      return MediaMetadata(
        url: url.trim(),
        title: filename,
        author: platform,
        platform: platform,
      );
    }

    // Try Cobalt API for social platforms
    try {
      final response = await _client.post(
        Uri.parse(cobaltApiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'url': url.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final title = data['filename'] ?? '${platform}_${DateTime.now().millisecondsSinceEpoch}';
        return MediaMetadata(
          url: url.trim(),
          title: title,
          author: platform,
          platform: platform,
          directDownloadUrl: data['url'],
        );
      }
    } catch (_) {
      // If Cobalt API fails or is unreachable, fallback to generic url
    }

    return MediaMetadata(
      url: url.trim(),
      title: '$platform Media',
      author: platform,
      platform: platform,
    );
  }

  /// Resolve stream for generic/Cobalt links
  Future<GenericStreamResult> resolveStream({
    required String url,
    required MediaType mediaType,
  }) async {
    // If direct link
    final uri = Uri.parse(url.trim());
    final path = uri.path.toLowerCase();

    if (path.endsWith('.mp4') || path.endsWith('.mp3') || path.endsWith('.m4a')) {
      final head = await _client.head(uri);
      final len = int.tryParse(head.headers['content-length'] ?? '0') ?? 0;
      final ext = path.endsWith('.mp3') ? 'mp3' : (path.endsWith('.m4a') ? 'm4a' : 'mp4');
      return GenericStreamResult(
        streamUrl: url.trim(),
        title: uri.pathSegments.last,
        extension: ext,
        totalBytes: len,
      );
    }

    // Attempt Cobalt resolve
    final response = await _client.post(
      Uri.parse(cobaltApiUrl),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'url': url.trim(),
        'downloadMode': mediaType == MediaType.audio ? 'audio' : 'auto',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final streamUrl = data['url'] as String?;
      if (streamUrl != null) {
        final ext = mediaType == MediaType.audio ? 'mp3' : 'mp4';
        return GenericStreamResult(
          streamUrl: streamUrl,
          title: data['filename'] ?? 'download_${DateTime.now().millisecondsSinceEpoch}',
          extension: ext,
          totalBytes: 0,
        );
      }
    }

    throw Exception('No se pudo resolver el enlace para esta plataforma');
  }
}

