import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoQuality;
import '../models/download_task.dart';
import '../models/media_metadata.dart';

/// Real mobile Chrome Android User-Agent header (Pixel 8 Pro, Chrome Mobile)
const String kMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/UQ1A.240105.004) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

/// Custom HTTP Client that injects mobile browser headers
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

/// Custom YoutubeHttpClient subclass for YoutubeExplode
class MobileYoutubeHttpClient extends YoutubeHttpClient {
  MobileYoutubeHttpClient([http.Client? client])
      : super(MobileHttpClient(client));

  @override
  Map<String, String> get headers => const {
        'user-agent': kMobileUserAgent,
        'accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
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
  final int containerTotalBytes;
  final String extension;
  final bool requiresAudioExtraction;

  ResolvedStream({
    required this.streamInfo,
    required this.stream,
    required this.totalBytes,
    int? containerTotalBytes,
    required this.extension,
    this.requiresAudioExtraction = false,
  }) : containerTotalBytes = containerTotalBytes ?? totalBytes;
}

class YoutubeExtractor {
  final YoutubeExplode _yt;
  final http.Client _httpClient;

  YoutubeExtractor({YoutubeExplode? yt, http.Client? httpClient})
      : _httpClient = httpClient ?? MobileHttpClient(),
        _yt = yt ?? YoutubeExplode(httpClient: MobileYoutubeHttpClient());

  // ─── Video ID extraction via Regex ─────────────────────────────────────────
  /// Extracts the 11-character YouTube video ID from any recognized URL format,
  /// including youtu.be short links, /shorts/, /embed/, and ?si= tracking params.
  static String? extractVideoId(String rawUrl) {
    final url = rawUrl.trim();
    final regex = RegExp(
      r'(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|live\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Cleans and returns a canonical YouTube watch URL without tracking garbage.
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
  /// Uses official YouTube oEmbed + Innertube stream manifest (requireWatchPage: false)
  /// to bypass web watch page bot walls and 429 rate limiting.
  Future<MediaMetadata> fetchMetadata(String url) async {
    try {
      final videoIdStr = extractVideoId(url) ?? url.trim();
      final videoId = VideoId(videoIdStr);

      String title = 'YouTube Video';
      String author = 'YouTube';
      String thumbnail = 'https://i.ytimg.com/vi/${videoId.value}/hqdefault.jpg';
      Duration? duration;

      // 1. Fetch metadata via official public oEmbed (never bot-blocked, instant)
      try {
        final oembedUri = Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId.value}&format=json',
        );
        final oembedRes = await _httpClient.get(oembedUri).timeout(
          const Duration(seconds: 8),
        );
        if (oembedRes.statusCode == 200) {
          final data = jsonDecode(oembedRes.body) as Map<String, dynamic>;
          title = data['title'] as String? ?? title;
          author = data['author_name'] as String? ?? author;
          if (data['thumbnail_url'] != null) {
            thumbnail = data['thumbnail_url'] as String;
          }
        }
      } catch (_) {
        // Fallback: Continue to manifest retrieval
      }

      // 2. Extract StreamManifest using Innertube Android endpoint (requireWatchPage: false)
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        requireWatchPage: false,
      );

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

      // Optional: attempt to get duration from video details if possible without blocking
      try {
        final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 4));
        duration = video.duration;
        if (video.title.isNotEmpty) title = video.title;
        if (video.author.isNotEmpty) author = video.author;
      } catch (_) {
        // Duration remains null or fallback if watch page was blocked; title and qualities are intact!
      }

      int? audioSizeBytes;
      int? videoSizeBytes;

      if (manifest.audioOnly.isNotEmpty) {
        audioSizeBytes = manifest.audioOnly.withHighestBitrate().size.totalBytes;
      }
      if (manifest.muxed.isNotEmpty) {
        videoSizeBytes = manifest.muxed.sortByVideoQuality().first.size.totalBytes;
      }

      return MediaMetadata(
        url: cleanUrl(url),
        title: title,
        author: author,
        thumbnailUrl: thumbnail,
        duration: duration,
        platform: 'YouTube',
        availableQualities: availableQualities.toList(),
        audioSizeBytes: audioSizeBytes,
        videoSizeBytes: videoSizeBytes,
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
  /// Uses requireWatchPage: false for 100% reliable local extraction.
  Future<ResolvedStream> resolveStream({
    required String url,
    required MediaType mediaType,
    VideoQuality quality = VideoQuality.best,
  }) async {
    try {
      final videoIdStr = extractVideoId(url) ?? url.trim();
      final videoId = VideoId(videoIdStr);

      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        requireWatchPage: false,
      );

      if (mediaType == MediaType.audio) {
        // YouTube adaptive audio-only streams (itag 140, 251) do NOT have ratebypass=yes
        // and are blocked with HTTP 403 Forbidden after 1 MB.
        // YouTube Muxed stream (itag 18: 360p MP4) ALWAYS has ratebypass=yes signed by YouTube
        // and contains an unthrottled, pristine 128kbps AAC stereo audio track.
        // We select itag 18, download it cleanly without any 403 errors, and extract the
        // audio track natively on device with Android's MediaExtractor.
        final muxedStreams = manifest.muxed.sortByVideoQuality();
        if (muxedStreams.isNotEmpty) {
          final selectedStream = muxedStreams.firstWhere(
            (s) => s.tag == 18,
            orElse: () => muxedStreams.last,
          );
          final stream = _yt.videos.streamsClient.get(selectedStream);
          final audioStreams = manifest.audioOnly;
          final estimatedAudioBytes = audioStreams.isNotEmpty
              ? audioStreams.withHighestBitrate().size.totalBytes
              : (selectedStream.size.totalBytes * 0.18).round();

          return ResolvedStream(
            streamInfo: selectedStream,
            stream: stream,
            totalBytes: estimatedAudioBytes,
            containerTotalBytes: selectedStream.size.totalBytes,
            extension: 'mp3',
            requiresAudioExtraction: true,
          );
        }

        // Fallback to audio-only if no muxed stream is available
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isEmpty) {
          throw Exception('No se encontraron pistas de audio disponibles');
        }

        final mp4AudioStreams = audioStreams
            .where((s) => s.container.name.toLowerCase() == 'mp4')
            .toList();
        final bestAudio = mp4AudioStreams.isNotEmpty
            ? mp4AudioStreams.withHighestBitrate()
            : audioStreams.withHighestBitrate();

        final stream = _yt.videos.streamsClient.get(bestAudio);

        return ResolvedStream(
          streamInfo: bestAudio,
          stream: stream,
          totalBytes: bestAudio.size.totalBytes,
          extension: 'mp3',
          requiresAudioExtraction: false,
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
          selectedStream = muxedStreams.first; // Mayor calidad muxed disponible
        } else {
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
    _httpClient.close();
  }
}
