import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoQuality;
import '../models/download_task.dart';
import '../models/media_metadata.dart';

/// Real mobile Chrome Android User-Agent header string (Pixel 8 Pro, Chrome 124)
const String kMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/UQ1A.240105.004; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.113 Mobile Safari/537.36';

/// Custom HTTP Client that injects mobile User-Agent and headers on EVERY request
class MobileHttpClient extends http.BaseClient {
  final http.Client _inner;

  MobileHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['user-agent'] = kMobileUserAgent;
    request.headers['sec-ch-ua'] =
        '"Chromium";v="124", "Not-A.Brand";v="99", "Google Chrome";v="124"';
    request.headers['sec-ch-ua-mobile'] = '?1';
    request.headers['sec-ch-ua-platform'] = '"Android"';
    request.headers['accept-language'] = 'es-419,es;q=0.9,en-US;q=0.8,en;q=0.7';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Custom YoutubeHttpClient subclass for YoutubeExplode with mobile browser headers
class MobileYoutubeHttpClient extends YoutubeHttpClient {
  MobileYoutubeHttpClient([http.Client? client])
      : super(MobileHttpClient(client));

  @override
  Map<String, String> get headers => const {
        'user-agent': kMobileUserAgent,
        'accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'accept-language': 'es-419,es;q=0.9,en-US;q=0.8,en;q=0.7',
        'sec-ch-ua':
            '"Chromium";v="124", "Not-A.Brand";v="99", "Google Chrome";v="124"',
        'sec-ch-ua-mobile': '?1',
        'sec-ch-ua-platform': '"Android"',
        'cookie': 'CONSENT=YES+cb',
      };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['user-agent'] = kMobileUserAgent;
    request.headers['sec-ch-ua-mobile'] = '?1';
    request.headers['sec-ch-ua-platform'] = '"Android"';
    return super.send(request);
  }
}

class ResolvedStream {
  final StreamInfo streamInfo;
  final Stream<List<int>> stream;
  final int totalBytes;
  final String extension;

  ResolvedStream({
    required this.streamInfo,
    required this.stream,
    required this.totalBytes,
    required this.extension,
  });
}

class YoutubeExtractor {
  final YoutubeExplode _yt;

  YoutubeExtractor({YoutubeExplode? yt})
      : _yt = yt ?? YoutubeExplode(httpClient: MobileYoutubeHttpClient());

  // ─── Video ID extraction via Regex ─────────────────────────────────────────
  /// Extracts the 11-character YouTube video ID from any recognized URL format,
  /// including youtu.be short links, /shorts/, /embed/, and ?si= tracking params.
  /// Returns null if the URL doesn't contain a recognizable video ID.
  static String? extractVideoId(String rawUrl) {
    final url = rawUrl.trim();
    final regex = RegExp(
      r'(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|live\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Cleans and returns a canonical YouTube watch URL without tracking garbage,
  /// or the trimmed URL if no YouTube ID is identified.
  static String cleanUrl(String rawUrl) {
    final videoId = extractVideoId(rawUrl);
    if (videoId != null && videoId.length == 11) {
      return 'https://www.youtube.com/watch?v=$videoId';
    }
    return rawUrl.trim();
  }

  /// Check if the URL is a recognized YouTube URL
  static bool isYoutubeUrl(String url) {
    if (extractVideoId(url) != null) return true;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('music.youtube.com');
  }

  /// Extract metadata and video details locally from YouTube.
  /// Throws user-friendly exceptions on network, host lookup, or rate-limit errors.
  Future<MediaMetadata> fetchMetadata(String url) async {
    try {
      // Extract clean video ID via Regex — strips tracking params (?si=..., etc.)
      final videoIdStr = extractVideoId(url) ?? url.trim();
      final videoId = VideoId(videoIdStr);

      final video = await _yt.videos.get(videoId);

      // Get available stream qualities from StreamManifest
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final availableQualities = <VideoQuality>{VideoQuality.best};

      for (final stream in manifest.muxed) {
        final height = stream.videoResolution.height;
        if (height >= 1080) {
          availableQualities.add(VideoQuality.p1080);
        } else if (height >= 720) {
          availableQualities.add(VideoQuality.p720);
        } else if (height >= 480) {
          availableQualities.add(VideoQuality.p480);
        } else if (height >= 360) {
          availableQualities.add(VideoQuality.p360);
        }
      }

      return MediaMetadata(
        url: cleanUrl(url),
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.mediumResUrl,
        duration: video.duration,
        platform: 'YouTube',
        availableQualities: availableQualities.toList(),
      );
    } on SocketException {
      throw Exception('Error de red: Comprueba tus datos móviles o Wi-Fi');
    } on VideoUnavailableException {
      throw Exception('El video no está disponible o es privado.');
    } on VideoUnplayableException {
      throw Exception(
        'El video tiene restricciones de edad o está bloqueado por YouTube',
      );
    } on TransientFailureException {
      throw Exception(
        'El video tiene restricciones de edad o está bloqueado por YouTube',
      );
    } on RequestLimitExceededException {
      throw Exception(
        'YouTube ha limitado las solicitudes temporalmente. '
        'Espera unos minutos e inténtalo de nuevo.',
      );
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('failed host lookup') ||
          str.contains('socket') ||
          str.contains('network') ||
          str.contains('errno = 7') ||
          str.contains('connection refused') ||
          str.contains('handshake failed') ||
          str.contains('timed out')) {
        throw Exception('Error de red: Comprueba tus datos móviles o Wi-Fi');
      }
      if (str.contains('unplayable') ||
          str.contains('age') ||
          str.contains('restricted') ||
          str.contains('login_required') ||
          str.contains('sign in') ||
          str.contains('transientfailure') ||
          str.contains('bot')) {
        throw Exception(
          'El video tiene restricciones de edad o está bloqueado por YouTube',
        );
      }
      throw Exception('No se pudo obtener la información del enlace: $e');
    }
  }

  /// Resolve the stream and return a stream reader with total bytes.
  /// Selects AudioOnlyStreamInfo with highest bitrate (for audio) or MuxedStreamInfo (for video).
  Future<ResolvedStream> resolveStream({
    required String url,
    required MediaType mediaType,
    VideoQuality quality = VideoQuality.best,
  }) async {
    try {
      final videoIdStr = extractVideoId(url) ?? url.trim();
      final videoId = VideoId(videoIdStr);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      if (mediaType == MediaType.audio) {
        // AudioOnlyStreamInfo con mayor bitrate
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isEmpty) {
          throw Exception('No se encontraron pistas de audio disponibles');
        }

        final bestAudio = audioStreams.withHighestBitrate();
        final stream = _yt.videos.streamsClient.get(bestAudio);

        return ResolvedStream(
          streamInfo: bestAudio,
          stream: stream,
          totalBytes: bestAudio.size.totalBytes,
          extension: bestAudio.container.name.toLowerCase() == 'webm'
              ? 'm4a'
              : bestAudio.container.name.toLowerCase(),
        );
      } else {
        // MuxedStreamInfo para video (incluye video y audio en un solo contenedor)
        final muxedStreams = manifest.muxed.sortByVideoQuality();
        if (muxedStreams.isEmpty) {
          // Fallback a video-only si no hay muxed
          final videoStreams = manifest.videoOnly.sortByVideoQuality();
          if (videoStreams.isEmpty) {
            throw Exception('No se encontraron pistas de video disponibles');
          }
          final streamInfo = videoStreams.first;
          return ResolvedStream(
            streamInfo: streamInfo,
            stream: _yt.videos.streamsClient.get(streamInfo),
            totalBytes: streamInfo.size.totalBytes,
            extension: streamInfo.container.name.toLowerCase(),
          );
        }

        MuxedStreamInfo selectedStream;
        final targetHeight = quality.heightPixels;

        if (targetHeight == null || quality == VideoQuality.best) {
          selectedStream = muxedStreams.first; // Highest quality muxed stream
        } else {
          // Encuentra el stream más cercano que coincida con la resolución deseada
          selectedStream = muxedStreams.firstWhere(
            (s) => s.videoResolution.height <= targetHeight,
            orElse: () => muxedStreams.last,
          );
        }

        final stream = _yt.videos.streamsClient.get(selectedStream);
        return ResolvedStream(
          streamInfo: selectedStream,
          stream: stream,
          totalBytes: selectedStream.size.totalBytes,
          extension: selectedStream.container.name.toLowerCase(),
        );
      }
    } on SocketException {
      throw Exception('Error de red: Comprueba tus datos móviles o Wi-Fi');
    } on VideoUnplayableException {
      throw Exception(
        'El video tiene restricciones de edad o está bloqueado por YouTube',
      );
    } on TransientFailureException {
      throw Exception(
        'El video tiene restricciones de edad o está bloqueado por YouTube',
      );
    } on RequestLimitExceededException {
      throw Exception(
        'YouTube ha limitado las solicitudes temporalmente. '
        'Espera unos minutos e inténtalo de nuevo.',
      );
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('failed host lookup') ||
          str.contains('socket') ||
          str.contains('network') ||
          str.contains('errno = 7')) {
        throw Exception('Error de red: Comprueba tus datos móviles o Wi-Fi');
      }
      if (str.contains('unplayable') ||
          str.contains('age') ||
          str.contains('restricted') ||
          str.contains('transientfailure')) {
        throw Exception(
          'El video tiene restricciones de edad o está bloqueado por YouTube',
        );
      }
      rethrow;
    }
  }

  void close() {
    _yt.close();
  }
}
