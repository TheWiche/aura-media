import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoQuality;
import '../../../../core/services/native_platform_service.dart';
import '../../../../core/services/settings_service.dart';
import '../models/download_task.dart';
import '../models/media_metadata.dart';

/// Mobile browser User-Agent used solely for oEmbed / public web endpoints.
const String kMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/UQ1A.240105.004) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

const String _kVisionOsUa =
    'com.google.visionos.youtube/1.04(RealityDevice17,1; U; CPU visionOS 26_6_0 like Mac OS X; en)';
const String _kYoutubeAndroidUa =
    'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
const String _kYoutubeIosUa =
    'com.google.ios.youtube/21.02.3 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';

/// Primary Innertube player client (visionOS over GAPIS) returning direct
/// un-gated adaptive audio/video URLs up to 4K without PO-Token 25% cutoffs.
const YoutubeApiClient kYoutubeVisionOsClient = YoutubeApiClient(
  {
    'context': {
      'client': {
        'clientName': 'VISIONOS',
        'clientVersion': '1.04',
        'clientScreen': 'WATCH',
        'platform': 'MOBILE',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'osName': 'visionOS',
        'osVersion': '26.6.0.23O770',
        'hl': 'en',
        'gl': 'US',
        'utcOffsetMinutes': 0,
      },
    },
    'contentCheckOk': true,
    'racyCheckOk': true,
  },
  'https://youtubei.googleapis.com/youtubei/v1/player?prettyPrint=false',
  headers: {
    'X-Goog-Api-Format-Version': '2',
  },
);

String _randomIdChars(int length) {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
  final rng = Random.secure();
  return List.generate(length, (_) => alphabet[rng.nextInt(alphabet.length)])
      .join();
}

/// HTTP client for general/oEmbed requests.
class MobileHttpClient extends http.BaseClient {
  final http.Client _inner;

  MobileHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['user-agent'] = kMobileUserAgent;
    request.headers['accept-language'] = 'es-419,es;q=0.9,en-US;q=0.8,en;q=0.7';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// YoutubeHttpClient tailored for `youtube_explode_dart`:
/// 1. Preserves each Innertube client's native User-Agent instead of injecting
///    conflicting Chrome `sec-ch-ua` headers onto Android/iOS/googlevideo URLs.
/// 2. Overrides `getStream` with safe 4 MB chunked Range transfers (`c=ANDROID`
///    and `c=ANDROID_VR`), per-request timeouts, and a strictly bounded 403
///    manifest refresh (fixing infinite hang loops at ~10 MB / 26%).
class AuraYoutubeHttpClient extends YoutubeHttpClient {
  final http.Client _rawClient;
  bool _isClosed = false;
  String? _visionOsVisitorData;
  final Map<String, String> _cpnByVideoId = {};

  AuraYoutubeHttpClient([super.client]) : _rawClient = client ?? http.Client();

  @override
  Map<String, String> get headers => const {
        'accept-language': 'en-US,en;q=0.9',
      };

  Future<String?> _ensureVisionOsVisitorData() async {
    if (_visionOsVisitorData != null) return _visionOsVisitorData;
    try {
      final res = await _rawClient
          .post(
            Uri.parse(
              'https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false',
            ),
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': _kVisionOsUa,
              'X-Goog-Api-Format-Version': '2',
            },
            body: jsonEncode({
              'context': kYoutubeVisionOsClient.payload['context'],
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final vd = decoded['responseContext']?['visitorData'] as String?;
          if (vd != null && vd.isNotEmpty) {
            _visionOsVisitorData = vd;
          }
        }
      }
    } catch (_) {}
    return _visionOsVisitorData;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isClosed || closed) throw HttpClientClosedException();

    final uri = request.url;

    // Shape VISIONOS player requests to match GAPIS requirements (t, id, cpn, visitorData).
    if (uri.host == 'youtubei.googleapis.com' &&
        uri.path.contains('/youtubei/v1/player') &&
        request is http.Request) {
      try {
        final bodyMap = jsonDecode(request.body) as Map<String, dynamic>;
        final clientMap = (bodyMap['context'] as Map<String, dynamic>)['client']
            as Map<String, dynamic>;
        if (clientMap['clientName'] == 'VISIONOS') {
          final vd = await _ensureVisionOsVisitorData();
          if (vd != null && vd.isNotEmpty) {
            clientMap['visitorData'] = vd;
          }
          final videoId = bodyMap['videoId'] as String? ?? '';
          final cpn = _randomIdChars(16);
          if (videoId.isNotEmpty) {
            _cpnByVideoId[videoId] = cpn;
          }
          bodyMap['cpn'] = cpn;

          final gapiUri = Uri.parse(
            'https://youtubei.googleapis.com/youtubei/v1/player'
            '?prettyPrint=false&t=${_randomIdChars(12)}&id=$videoId',
          );
          final rebuilt = http.Request(request.method, gapiUri);
          rebuilt.body = jsonEncode(bodyMap);
          rebuilt.headers['Content-Type'] = 'application/json';
          rebuilt.headers['User-Agent'] = _kVisionOsUa;
          rebuilt.headers['X-Goog-Api-Format-Version'] = '2';
          return _rawClient.send(rebuilt);
        }
      } catch (_) {}
    }

    if (uri.host.contains('googlevideo.com')) {
      final c = uri.queryParameters['c'] ?? '';
      if (request.method.toUpperCase() == 'HEAD') {
        final ranged = (c == 'VISIONOS' || c == 'IOS') &&
                !uri.queryParameters.containsKey('range')
            ? uri.replace(
                queryParameters: {...uri.queryParameters, 'range': '0-1'},
              )
            : uri;
        final rebuilt = http.Request('HEAD', ranged)
          ..persistentConnection = false;
        if (c == 'VISIONOS') {
          rebuilt.headers['user-agent'] = _kVisionOsUa;
        } else if (c.startsWith('ANDROID')) {
          rebuilt.headers['user-agent'] = _kYoutubeAndroidUa;
        } else if (c == 'IOS') {
          rebuilt.headers['user-agent'] = _kYoutubeIosUa;
        }
        return _rawClient.send(rebuilt);
      }

      if (c == 'VISIONOS') {
        request.headers['user-agent'] = _kVisionOsUa;
      } else if (c.startsWith('ANDROID')) {
        request.headers['user-agent'] = _kYoutubeAndroidUa;
      } else if (c == 'IOS') {
        request.headers['user-agent'] = _kYoutubeIosUa;
      }
      request.headers.remove('sec-ch-ua');
      request.headers.remove('sec-ch-ua-mobile');
      request.headers.remove('sec-ch-ua-platform');
      request.headers.remove('cookie');
    } else if (!uri.path.contains('/youtubei/') &&
        !request.headers.containsKey('user-agent')) {
      request.headers['user-agent'] = kMobileUserAgent;
    }

    return _rawClient.send(request);
  }

  @override
  Stream<List<int>> getStream(
    StreamInfo streamInfo, {
    Map<String, String> headers = const {},
    bool validate = true,
    int start = 0,
    int errorCount = 0,
    required StreamClient streamClient,
  }) {
    if (streamInfo.fragments.isNotEmpty ||
        streamInfo is HlsMuxedStreamInfo ||
        streamInfo is HlsAudioStreamInfo ||
        streamInfo is HlsVideoStreamInfo) {
      return super.getStream(
        streamInfo,
        headers: headers,
        validate: validate,
        start: start,
        errorCount: errorCount,
        streamClient: streamClient,
      );
    }

    return _streamChunkedSafe(
      streamInfo,
      streamClient: streamClient,
      start: start,
    );
  }

  Stream<List<int>> _streamChunkedSafe(
    StreamInfo initialInfo, {
    required StreamClient streamClient,
    int start = 0,
  }) async* {
    const int chunkSize = 4 * 1024 * 1024; // 4 MB chunks avoid CDN stalls & limits
    const int maxManifestRefreshes = 2;
    const int maxTransientErrors = 3;

    var currentInfo = initialInfo;
    var url = initialInfo.url;
    final totalBytes = initialInfo.size.totalBytes;
    var bytesCount = start;
    int manifestRefreshes = 0;
    int transientErrors = 0;

    while (!_isClosed && !closed && (totalBytes <= 0 || bytesCount < totalBytes)) {
      final from = bytesCount;
      final to = totalBytes > 0
          ? ((from + chunkSize < totalBytes)
              ? (from + chunkSize - 1)
              : (totalBytes - 1))
          : (from + chunkSize - 1);

      http.StreamedResponse? response;
      try {
        final c = url.queryParameters['c'] ?? '';
        final usesRangeHeader = c.startsWith('ANDROID');
        final cpn = c == 'VISIONOS'
            ? _cpnByVideoId[currentInfo.videoId.value]
            : null;

        final Uri reqUri = usesRangeHeader
            ? url
            : url.replace(queryParameters: {
                ...url.queryParameters,
                if (cpn != null && !url.queryParameters.containsKey('cpn'))
                  'cpn': cpn,
                'range': '$from-$to',
              });

        final req = http.Request('GET', reqUri);
        if (usesRangeHeader) {
          req.headers['Range'] = 'bytes=$from-$to';
          req.headers['user-agent'] = _kYoutubeAndroidUa;
        } else if (c == 'VISIONOS') {
          req.headers['user-agent'] = _kVisionOsUa;
        } else if (c == 'IOS') {
          req.headers['user-agent'] = _kYoutubeIosUa;
        }

        response = await _rawClient
            .send(req)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          int chunkBytesReceived = 0;
          await for (final chunk
              in response.stream.timeout(const Duration(seconds: 25))) {
            if (_isClosed || closed) break;
            bytesCount += chunk.length;
            chunkBytesReceived += chunk.length;
            yield chunk;
          }
          transientErrors = 0;

          if (totalBytes <= 0) {
            break;
          }
          if (chunkBytesReceived == 0 && bytesCount < totalBytes) {
            throw const SocketException('Empty stream chunk before EOF');
          }
          continue;
        }

        final statusCode = response.statusCode;
        await response.stream.drain<void>().catchError((_) {});

        if (statusCode == 403 || statusCode == 410) {
          manifestRefreshes++;
          if (manifestRefreshes > maxManifestRefreshes) {
            throw Exception(
              'YouTube bloqueó el acceso a este flujo (HTTP $statusCode). '
              'Prueba otra calidad o formato.',
            );
          }

          _visionOsVisitorData = null;
          final refreshed = await _refreshStreamInfo(
            streamClient,
            currentInfo,
            attempt: manifestRefreshes,
          );
          if (refreshed == null) {
            throw Exception(
              'El enlace de descarga expiró (HTTP $statusCode) y no pudo renovarse.',
            );
          }
          currentInfo = refreshed;
          url = refreshed.url;
          continue;
        }

        if (statusCode == 429 || statusCode >= 500) {
          transientErrors++;
          if (transientErrors > maxTransientErrors) {
            throw Exception(
              'YouTube limitó temporalmente la descarga (HTTP $statusCode).',
            );
          }
          await Future.delayed(Duration(milliseconds: 500 * transientErrors));
          continue;
        }

        throw Exception('Error HTTP $statusCode al descargar flujo multimedia');
      } on HttpClientClosedException {
        break;
      } catch (e) {
        if (e.toString().contains('YouTube bloqueó') ||
            e.toString().contains('expiró') ||
            e.toString().contains('Error HTTP')) {
          rethrow;
        }
        transientErrors++;
        if (transientErrors > maxTransientErrors) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 450 * transientErrors));
      }
    }
  }

  Future<StreamInfo?> _refreshStreamInfo(
    StreamClient streamClient,
    StreamInfo target, {
    required int attempt,
  }) async {
    final clients = attempt == 1
        ? const [
            [kYoutubeVisionOsClient],
            [YoutubeApiClient.androidVr],
            [YoutubeApiClient.androidSdkless],
          ]
        : const [
            [YoutubeApiClient.androidSdkless],
            [kYoutubeVisionOsClient],
            [YoutubeApiClient.tv],
          ];

    for (final clientList in clients) {
      try {
        final manifest = await streamClient
            .getManifest(
              target.videoId,
              ytClients: clientList,
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 10));
        for (final s in manifest.streams) {
          if (s.tag == target.tag) return s;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  void close() {
    _isClosed = true;
    _rawClient.close();
    super.close();
  }
}

class ResolvedStream {
  final StreamInfo streamInfo;
  final Stream<List<int>> stream;
  final StreamInfo? secondaryAudioInfo;
  final Stream<List<int>>? secondaryAudioStream;
  final int totalBytes;
  final int containerTotalBytes;
  final int secondaryAudioBytes;
  final String extension;
  final bool requiresAudioExtraction;
  final bool requiresVideoAudioMux;

  ResolvedStream({
    required this.streamInfo,
    required this.stream,
    this.secondaryAudioInfo,
    this.secondaryAudioStream,
    required this.totalBytes,
    int? containerTotalBytes,
    this.secondaryAudioBytes = 0,
    required this.extension,
    this.requiresAudioExtraction = false,
    this.requiresVideoAudioMux = false,
  }) : containerTotalBytes = containerTotalBytes ?? totalBytes;

  bool get isDualAdaptive =>
      requiresVideoAudioMux &&
      secondaryAudioInfo != null &&
      secondaryAudioStream != null;
}

class YoutubeExtractor {
  final YoutubeExplode _yt;
  final http.Client _httpClient;

  YoutubeExtractor({YoutubeExplode? yt, http.Client? httpClient})
      : _httpClient = httpClient ?? MobileHttpClient(),
        _yt = yt ?? YoutubeExplode(httpClient: AuraYoutubeHttpClient());

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

  /// Awaits complete metadata and stream options (compatible with existing callers/tests).
  Future<MediaMetadata> fetchMetadata(String url) {
    return fetchMetadataProgressive(url, onProgress: (_) {});
  }

  /// Progressive multi-stage extraction:
  /// - Stage 0 (`instant`, 0 ms): Video ID, canonical URL & immediate HQ thumbnail.
  /// - Stage 1A (`basicInfo`, ~250-400 ms): oEmbed title, author, thumbnail.
  /// - Stage 1B (`streamsReady`, ~300-600 ms in parallel): Innertube `androidVr`
  ///   manifest with full resolutions (up to 4K60), codecs & audio bitrates.
  /// - Stage 2 (`enriching` -> `complete`): duration + complementary fallback merge.
  Future<MediaMetadata> fetchMetadataProgressive(
    String url, {
    required void Function(MediaMetadata partial) onProgress,
  }) async {
    try {
      final videoIdStr = extractVideoId(url) ?? url.trim();
      final videoId = VideoId(videoIdStr);
      final canonicalUrl = cleanUrl(url);
      final defaultThumb =
          'https://i.ytimg.com/vi/${videoId.value}/hqdefault.jpg';

      var snapshot = MediaMetadata(
        url: canonicalUrl,
        title: 'Cargando video de YouTube...',
        author: 'YouTube',
        thumbnailUrl: defaultThumb,
        platform: 'YouTube',
        availableQualities: const [VideoQuality.best],
        analysisStage: AnalysisStage.instant,
      );
      onProgress(snapshot);

      final sdkInt = await NativePlatformService.instance.getAndroidSdkInt();
      final allowAv1InMp4 = sdkInt >= 29;

      final oembedFuture = _fetchOembed(videoId.value).then((data) {
        if (data == null) return false;
        final title = (data['title'] as String?)?.trim();
        final author = (data['author_name'] as String?)?.trim();
        final thumb = (data['thumbnail_url'] as String?)?.trim();

        final nextStage = snapshot.analysisStage.hasStreams
            ? snapshot.analysisStage
            : AnalysisStage.basicInfo;

        snapshot = snapshot.copyWith(
          title: (title != null && title.isNotEmpty) ? title : snapshot.title,
          author:
              (author != null && author.isNotEmpty) ? author : snapshot.author,
          thumbnailUrl: (thumb != null && thumb.isNotEmpty)
              ? thumb
              : snapshot.thumbnailUrl,
          analysisStage: nextStage,
        );
        onProgress(snapshot);
        return true;
      }).catchError((_) => false);

      final watchDetailsFuture = _yt.videos
          .get(videoId)
          .timeout(const Duration(seconds: 5))
          .then<Video?>((video) {
        final nextStage = snapshot.analysisStage;
        snapshot = snapshot.copyWith(
          title: video.title.isNotEmpty &&
                  snapshot.title == 'Cargando video de YouTube...'
              ? video.title
              : (video.title.isNotEmpty && !snapshot.analysisStage.hasBasicInfo
                  ? video.title
                  : snapshot.title),
          author: video.author.isNotEmpty ? video.author : snapshot.author,
          duration: video.duration ?? snapshot.duration,
          analysisStage: nextStage,
        );
        onProgress(snapshot);
        return video;
      }).catchError((_) => null);

      final manifestResult = await _getFastManifest(videoId);
      final manifest = manifestResult.manifest;

      var parsed = _buildOptionsFromManifest(
        manifest,
        allowAv1InMp4: allowAv1InMp4,
      );

      if (snapshot.title == 'Cargando video de YouTube...') {
        await oembedFuture.timeout(
          const Duration(milliseconds: 250),
          onTimeout: () => false,
        );
      }

      final resolvedTitle = snapshot.title == 'Cargando video de YouTube...'
          ? 'Video de YouTube (${videoId.value})'
          : snapshot.title;

      snapshot = snapshot.copyWith(
        title: resolvedTitle,
        availableQualities: parsed.availableQualities,
        videoOptions: parsed.videoOptions,
        audioOptions: parsed.audioOptions,
        audioSizeBytes: parsed.defaultAudioSizeBytes,
        videoSizeBytes: parsed.defaultVideoSizeBytes,
        analysisStage: AnalysisStage.streamsReady,
      );
      onProgress(snapshot);

      final needsFallbackMerge = parsed.videoOptions.every((v) => v.height <= 360) ||
          parsed.audioOptions.length <= 1;

      if (needsFallbackMerge &&
          manifestResult.client != YoutubeApiClient.androidSdkless) {
        snapshot = snapshot.copyWith(analysisStage: AnalysisStage.enriching);
        onProgress(snapshot);

        try {
          final secondary = await _yt.videos.streamsClient
              .getManifest(
                videoId,
                ytClients: const [YoutubeApiClient.androidSdkless],
                requireWatchPage: false,
              )
              .timeout(const Duration(seconds: 6));
          final mergedStreams = <StreamInfo>[
            ...manifest.streams,
            ...secondary.streams,
          ];
          parsed = _buildOptionsFromManifest(
            StreamManifest(mergedStreams),
            allowAv1InMp4: allowAv1InMp4,
          );
          snapshot = snapshot.copyWith(
            availableQualities: parsed.availableQualities,
            videoOptions: parsed.videoOptions,
            audioOptions: parsed.audioOptions,
            audioSizeBytes: parsed.defaultAudioSizeBytes,
            videoSizeBytes: parsed.defaultVideoSizeBytes,
          );
          onProgress(snapshot);
        } catch (_) {}
      }

      await Future.wait([
        oembedFuture,
        watchDetailsFuture,
      ]);

      final finalTitle = snapshot.title == 'Cargando video de YouTube...'
          ? 'Video de YouTube (${videoId.value})'
          : snapshot.title;

      snapshot = snapshot.copyWith(
        title: finalTitle,
        analysisStage: AnalysisStage.complete,
      );
      onProgress(snapshot);
      return snapshot;
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
      throw _mapFriendlyException(e);
    }
  }

  /// Resolves either a single stream (muxed video, WebM Opus, M4A/MP3 audio)
  /// or a dual adaptive pair (high-res videoOnly + compatible audioOnly) to mux natively.
  Future<ResolvedStream> resolveStream({
    required String url,
    required MediaType mediaType,
    VideoQuality quality = VideoQuality.best,
    String audioExtension = 'mp3',
    VideoFormatPreference preferredVideoFormat = VideoFormatPreference.auto,
    int? videoItag,
    int? audioItag,
    String? audioLanguage,
    bool forceMuxedFallback = false,
  }) async {
    try {
      final videoIdStr = extractVideoId(url) ?? url.trim();
      final videoId = VideoId(videoIdStr);
      final manifestResult = await _getFastManifest(
        videoId,
        requireMuxed: forceMuxedFallback,
      );
      var manifest = manifestResult.manifest;
      final sdkInt = await NativePlatformService.instance.getAndroidSdkInt();

      if (mediaType == MediaType.audio) {
        if (!forceMuxedFallback && manifest.audioOnly.isNotEmpty) {
          final selectedAudio = _pickAudioStream(
            manifest,
            audioExtension: audioExtension,
            requestedItag: audioItag,
            audioLanguage: audioLanguage,
          );

          if (selectedAudio != null) {
            final isWebm = audioExtension.toLowerCase() == 'webm' ||
                selectedAudio.container.name.toLowerCase() == 'webm';

            final effectiveExt = isWebm
                ? 'webm'
                : (audioExtension.toLowerCase() == 'm4a' ? 'm4a' : 'mp3');

            return ResolvedStream(
              streamInfo: selectedAudio,
              stream: _yt.videos.streamsClient.get(selectedAudio),
              totalBytes: selectedAudio.size.totalBytes,
              containerTotalBytes: selectedAudio.size.totalBytes,
              extension: effectiveExt,
              requiresAudioExtraction: !isWebm,
              requiresVideoAudioMux: false,
            );
          }
        }

        // Fallback: ensure muxed itag 18 is present (visionOS doesn't emit muxed)
        if (manifest.muxed.isEmpty) {
          try {
            manifest = (await _getFastManifest(videoId, requireMuxed: true))
                .manifest;
          } catch (_) {}
        }
        final muxedStreams = manifest.muxed.sortByVideoQuality();
        if (muxedStreams.isNotEmpty) {
          final selectedStream = muxedStreams.firstWhere(
            (s) => s.tag == 18,
            orElse: () => muxedStreams.last,
          );
          final audioStreams = manifest.audioOnly;
          final estimatedAudioBytes = audioStreams.isNotEmpty
              ? audioStreams.withHighestBitrate().size.totalBytes
              : (selectedStream.size.totalBytes * 0.18).round();

          return ResolvedStream(
            streamInfo: selectedStream,
            stream: _yt.videos.streamsClient.get(selectedStream),
            totalBytes: estimatedAudioBytes,
            containerTotalBytes: selectedStream.size.totalBytes,
            extension: audioExtension == 'webm' ? 'm4a' : audioExtension,
            requiresAudioExtraction: true,
            requiresVideoAudioMux: false,
          );
        }

        throw Exception('No se encontraron pistas de audio disponibles');
      }

      // ─── VIDEO RESOLUTION ────────────────────────────────────────────────
      if (videoItag != null) {
        final muxedMatch =
            manifest.muxed.where((s) => s.tag == videoItag).toList();
        if (muxedMatch.isNotEmpty) {
          final m = muxedMatch.first;
          return ResolvedStream(
            streamInfo: m,
            stream: _yt.videos.streamsClient.get(m),
            totalBytes: m.size.totalBytes,
            containerTotalBytes: m.size.totalBytes,
            extension: 'mp4',
          );
        }

        final videoOnlyMatch =
            manifest.videoOnly.where((s) => s.tag == videoItag).toList();
        if (videoOnlyMatch.isNotEmpty) {
          final v = videoOnlyMatch.first;
          return _buildAdaptiveVideoPlan(
            manifest,
            v,
            requestedAudioItag: audioItag,
            audioLanguage: audioLanguage,
          );
        }
      }

      if (!forceMuxedFallback && manifest.videoOnly.isNotEmpty) {
        final bestVideoOnly = _pickVideoOnlyStream(
          manifest,
          quality: quality,
          preference: preferredVideoFormat,
          allowAv1InMp4: sdkInt >= 29,
        );

        if (bestVideoOnly != null) {
          final is360Mp4 = quality == VideoQuality.p360 &&
              preferredVideoFormat != VideoFormatPreference.webm &&
              manifest.muxed.any((m) => m.videoResolution.height == 360);
          if (!is360Mp4) {
            return _buildAdaptiveVideoPlan(
              manifest,
              bestVideoOnly,
              requestedAudioItag: audioItag,
              audioLanguage: audioLanguage,
            );
          }
        }
      }

      final muxedStreams = manifest.muxed.sortByVideoQuality();
      if (muxedStreams.isNotEmpty) {
        final targetHeight = quality.heightPixels;
        final selectedStream =
            (targetHeight == null || quality == VideoQuality.best)
                ? muxedStreams.first
                : muxedStreams.firstWhere(
                    (s) => s.videoResolution.height <= targetHeight,
                    orElse: () => muxedStreams.last,
                  );

        return ResolvedStream(
          streamInfo: selectedStream,
          stream: _yt.videos.streamsClient.get(selectedStream),
          totalBytes: selectedStream.size.totalBytes,
          containerTotalBytes: selectedStream.size.totalBytes,
          extension: selectedStream.container.name.toLowerCase(),
        );
      }

      throw Exception('No se encontraron pistas de video disponibles');
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
      final mapped = _mapFriendlyException(e);
      if (mapped == e) rethrow;
      throw mapped;
    }
  }

  ResolvedStream _buildAdaptiveVideoPlan(
    StreamManifest manifest,
    VideoOnlyStreamInfo video, {
    int? requestedAudioItag,
    String? audioLanguage,
  }) {
    final container = video.container.name.toLowerCase();
    final isWebm = container == 'webm';

    AudioOnlyStreamInfo? audio;
    if (requestedAudioItag != null) {
      final exact =
          manifest.audioOnly.where((s) => s.tag == requestedAudioItag).toList();
      if (exact.isNotEmpty) {
        final candidate = exact.first;
        final candidateWebm = candidate.container.name.toLowerCase() == 'webm';
        if (candidateWebm == isWebm) {
          audio = candidate;
        }
      }
    }

    audio ??= _pickAudioStream(
      manifest,
      audioExtension: isWebm ? 'webm' : 'm4a',
      audioLanguage: audioLanguage,
    );

    if (audio == null && manifest.audioOnly.isNotEmpty) {
      audio = manifest.audioOnly.withHighestBitrate();
    }

    if (audio != null) {
      final vBytes = video.size.totalBytes;
      final aBytes = audio.size.totalBytes;
      return ResolvedStream(
        streamInfo: video,
        stream: _yt.videos.streamsClient.get(video),
        secondaryAudioInfo: audio,
        secondaryAudioStream: _yt.videos.streamsClient.get(audio),
        totalBytes: vBytes + aBytes,
        containerTotalBytes: vBytes,
        secondaryAudioBytes: aBytes,
        extension: isWebm ? 'webm' : 'mp4',
        requiresAudioExtraction: false,
        requiresVideoAudioMux: true,
      );
    }

    return ResolvedStream(
      streamInfo: video,
      stream: _yt.videos.streamsClient.get(video),
      totalBytes: video.size.totalBytes,
      containerTotalBytes: video.size.totalBytes,
      extension: isWebm ? 'webm' : 'mp4',
      requiresVideoAudioMux: false,
    );
  }

  Future<Map<String, dynamic>?> _fetchOembed(String videoId) async {
    try {
      final uri = Uri.parse(
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json',
      );
      final res =
          await _httpClient.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<_ManifestFetchResult> _getFastManifest(
    VideoId videoId, {
    bool requireMuxed = false,
  }) async {
    final clients = requireMuxed
        ? const [
            YoutubeApiClient.androidSdkless,
            YoutubeApiClient.androidVr,
            YoutubeApiClient.tv,
          ]
        : const [
            kYoutubeVisionOsClient,
            YoutubeApiClient.androidVr,
            YoutubeApiClient.androidSdkless,
            YoutubeApiClient.tv,
          ];
    for (final client in clients) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [client],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 9));
        if (requireMuxed && manifest.muxed.isEmpty) {
          continue;
        }
        if (manifest.streams.isNotEmpty) {
          return _ManifestFetchResult(manifest: manifest, client: client);
        }
      } catch (e) {
        if (client == clients.last) rethrow;
      }
    }
    throw VideoUnavailableException('No streams available for $videoId');
  }

  static _ParsedManifestOptions _buildOptionsFromManifest(
    StreamManifest manifest, {
    required bool allowAv1InMp4,
  }) {
    final allAudio = manifest.audioOnly.toList()
      ..sort(
        (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
      );

    final aacStreams = allAudio.where((s) {
      final c = s.container.name.toLowerCase();
      final codec = s.audioCodec.toLowerCase();
      return c == 'mp4' &&
          (codec.contains('mp4a') || codec.contains('aac')) &&
          s.tag != 258 &&
          s.tag != 328 &&
          s.tag != 380;
    }).toList();

    final opusStreams = allAudio.where((s) {
      final c = s.container.name.toLowerCase();
      final codec = s.audioCodec.toLowerCase();
      return c == 'webm' && codec.contains('opus');
    }).toList();

    final defaultAac = aacStreams.isNotEmpty
        ? aacStreams.firstWhere(
            (s) => s.tag == 140,
            orElse: () => aacStreams.first,
          )
        : null;
    final defaultOpus = opusStreams.isNotEmpty
        ? opusStreams.firstWhere(
            (s) => s.tag == 251,
            orElse: () => opusStreams.first,
          )
        : null;

    final audioOptions = <AudioStreamOption>[];
    final seenAudioKeys = <String>{};

    void addAudioOption(
      AudioOnlyStreamInfo s,
      AudioFileFormat format,
      String ext,
    ) {
      final kbps = s.bitrate.kiloBitsPerSecond.round();
      final lang = s.audioTrack?.displayName;
      final isDefault = s.audioTrack?.audioIsDefault ?? true;
      final key = '${format.name}_${s.tag}_${lang ?? ''}';
      if (!seenAudioKeys.add(key)) return;

      final tier = _audioTierLabel(kbps, format);
      final codecLabel = switch (format) {
        AudioFileFormat.mp3 => 'AAC → MP3 compat.',
        AudioFileFormat.m4a =>
          s.audioCodec.contains('.5') ? 'HE-AAC' : 'AAC-LC',
        AudioFileFormat.webm => 'Opus WebM',
      };
      final note = switch (format) {
        AudioFileFormat.mp3 =>
          kbps <= 65 ? 'Ligero · compatible universal' : 'Compatible universal',
        AudioFileFormat.m4a => kbps >= 180
            ? 'AAC multicanal alta tasa'
            : (kbps <= 65 ? 'Ahorro de datos' : 'Nativo iOS/Android'),
        AudioFileFormat.webm =>
          kbps >= 110 ? 'Máx. fidelidad por MB' : 'Ligero en Opus',
      };

      audioOptions.add(
        AudioStreamOption(
          id: key,
          format: format,
          extension: ext,
          codecLabel: codecLabel,
          bitrateKbps: kbps,
          qualityTier: tier,
          sizeBytes: s.size.totalBytes,
          itag: s.tag,
          trackLanguage: lang,
          isDefaultTrack: isDefault,
          note: note,
        ),
      );
    }

    for (final s in aacStreams) {
      addAudioOption(s, AudioFileFormat.mp3, 'mp3');
      addAudioOption(s, AudioFileFormat.m4a, 'm4a');
    }
    for (final s in opusStreams) {
      addAudioOption(s, AudioFileFormat.webm, 'webm');
    }

    final videoOptions = <VideoStreamOption>[];
    final seenVideoKeys = <String>{};

    final sortedVideoOnly = manifest.videoOnly.sortByVideoQuality();
    for (final v in sortedVideoOnly) {
      final container = v.container.name.toLowerCase();
      final rawCodec = v.videoCodec.toLowerCase();
      final readableCodec = _readableVideoCodec(rawCodec);

      if (readableCodec == 'AV1' && !allowAv1InMp4 && container == 'mp4') {
        continue;
      }

      final isWebm = container == 'webm';
      if (isWebm && readableCodec != 'VP9' && readableCodec != 'VP8') continue;
      if (!isWebm &&
          readableCodec != 'H.264' &&
          readableCodec != 'AV1' &&
          readableCodec != 'H.265') {
        continue;
      }

      final pairedAudio = isWebm ? (defaultOpus ?? defaultAac) : defaultAac;
      if (pairedAudio == null && manifest.muxed.isEmpty) continue;

      final height = v.videoResolution.height;
      final quality = VideoQualityExtension.fromHeight(height);
      final fps = v.framerate.framesPerSecond.round();
      final isHdr = v.qualityLabel.toUpperCase().contains('HDR');
      final fpsBucket = fps >= 48 ? 60 : 30;
      final key = '${height}_${fpsBucket}_${container}_${readableCodec}_$isHdr';
      if (!seenVideoKeys.add(key)) continue;

      final compatNote = switch (readableCodec) {
        'H.264' => 'Máxima compatibilidad (TV, galería, redes)',
        'VP9' => height >= 1440
            ? 'Ultra HD hasta 4K · WebM nativo'
            : 'Alta compresión (-40% peso)',
        'AV1' => 'Ultra ligero · Android 10+',
        _ => 'Video adaptativo',
      };

      videoOptions.add(
        VideoStreamOption(
          id: '${v.tag}+${pairedAudio?.tag ?? 0}',
          quality: quality,
          height: height,
          width: v.videoResolution.width,
          fps: fps,
          container: isWebm ? 'webm' : 'mp4',
          videoCodec: readableCodec,
          rawVideoCodec: v.videoCodec,
          audioCodec: isWebm ? 'Opus' : 'AAC',
          videoItag: v.tag,
          audioItag: pairedAudio?.tag,
          isMuxed: false,
          isHdr: isHdr,
          videoSizeBytes: v.size.totalBytes,
          audioSizeBytes: pairedAudio?.size.totalBytes ?? 0,
          bitrateKbps: v.bitrate.kiloBitsPerSecond.round(),
          compatibilityNote: compatNote,
        ),
      );
    }

    for (final m in manifest.muxed.sortByVideoQuality()) {
      final height = m.videoResolution.height;
      final quality = VideoQualityExtension.fromHeight(height);
      final fps = m.framerate.framesPerSecond.round();
      final key = '${height}_muxed_${m.tag}';
      if (!seenVideoKeys.add(key)) continue;

      videoOptions.add(
        VideoStreamOption(
          id: '${m.tag}',
          quality: quality,
          height: height,
          width: m.videoResolution.width,
          fps: fps,
          container: 'mp4',
          videoCodec: 'H.264 Directo',
          rawVideoCodec: m.videoCodec,
          audioCodec: 'AAC',
          videoItag: m.tag,
          audioItag: null,
          isMuxed: true,
          videoSizeBytes: m.size.totalBytes,
          audioSizeBytes: 0,
          bitrateKbps: m.bitrate.kiloBitsPerSecond.round(),
          compatibilityNote: 'Descarga directa en 1 paso (más rápida)',
        ),
      );
    }

    videoOptions.sort((a, b) {
      final h = b.height.compareTo(a.height);
      if (h != 0) return h;
      final f = b.fps.compareTo(a.fps);
      if (f != 0) return f;
      int codecRank(VideoStreamOption o) {
        if (o.isMuxed && o.height <= 360) return 0;
        if (o.videoCodec == 'H.264') return 1;
        if (o.videoCodec == 'VP9') return 2;
        if (o.videoCodec == 'AV1') return 3;
        return 4;
      }

      return codecRank(a).compareTo(codecRank(b));
    });

    final qualities = <VideoQuality>{VideoQuality.best};
    for (final opt in videoOptions) {
      qualities.add(opt.quality);
    }

    return _ParsedManifestOptions(
      availableQualities: qualities.toList(),
      videoOptions: videoOptions,
      audioOptions: audioOptions,
      defaultAudioSizeBytes:
          defaultAac?.size.totalBytes ?? defaultOpus?.size.totalBytes,
      defaultVideoSizeBytes:
          videoOptions.isNotEmpty ? videoOptions.first.totalSizeBytes : null,
    );
  }

  static AudioOnlyStreamInfo? _pickAudioStream(
    StreamManifest manifest, {
    required String audioExtension,
    int? requestedItag,
    String? audioLanguage,
  }) {
    final audioStreams = manifest.audioOnly.toList()
      ..sort(
        (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
      );
    if (audioStreams.isEmpty) return null;

    if (requestedItag != null) {
      final exact = audioStreams.where((s) => s.tag == requestedItag).toList();
      if (exact.isNotEmpty) return exact.first;
    }

    final wantWebm = audioExtension.toLowerCase() == 'webm';
    final filtered = audioStreams.where((s) {
      final c = s.container.name.toLowerCase();
      final codec = s.audioCodec.toLowerCase();
      if (wantWebm) return c == 'webm' && codec.contains('opus');
      return c == 'mp4' &&
          (codec.contains('mp4a') || codec.contains('aac')) &&
          s.tag != 258 &&
          s.tag != 328 &&
          s.tag != 380;
    }).toList();

    final pool = filtered.isNotEmpty ? filtered : audioStreams;

    if (audioLanguage != null && audioLanguage.isNotEmpty) {
      final langMatches = pool
          .where((s) => s.audioTrack?.displayName == audioLanguage)
          .toList();
      if (langMatches.isNotEmpty) {
        return langMatches.firstWhere(
          (s) => wantWebm ? s.tag == 251 : s.tag == 140,
          orElse: () => langMatches.first,
        );
      }
    }

    return pool.firstWhere(
      (s) => wantWebm ? s.tag == 251 : s.tag == 140,
      orElse: () => pool.first,
    );
  }

  static VideoOnlyStreamInfo? _pickVideoOnlyStream(
    StreamManifest manifest, {
    required VideoQuality quality,
    required VideoFormatPreference preference,
    required bool allowAv1InMp4,
  }) {
    final all = manifest.videoOnly.sortByVideoQuality();
    if (all.isEmpty) return null;

    final targetHeight = quality.heightPixels;
    final heightFiltered = (targetHeight == null || quality == VideoQuality.best)
        ? all
        : all.where((s) => s.videoResolution.height <= targetHeight).toList();

    final pool = heightFiltered.isNotEmpty ? heightFiltered : all;

    final topHeight = pool.first.videoResolution.height;
    final topCandidates =
        pool.where((s) => s.videoResolution.height == topHeight).toList();

    bool isH264(VideoOnlyStreamInfo s) =>
        s.videoCodec.toLowerCase().contains('avc');
    bool isVp9(VideoOnlyStreamInfo s) =>
        s.container.name.toLowerCase() == 'webm' &&
        s.videoCodec.toLowerCase().contains('vp9');
    bool isAv1(VideoOnlyStreamInfo s) =>
        allowAv1InMp4 && s.videoCodec.toLowerCase().contains('av01');

    if (preference == VideoFormatPreference.mp4) {
      return topCandidates.firstWhere(
        isH264,
        orElse: () => topCandidates.firstWhere(
          isAv1,
          orElse: () =>
              pool.firstWhere(isH264, orElse: () => topCandidates.first),
        ),
      );
    }

    if (preference == VideoFormatPreference.webm) {
      return topCandidates.firstWhere(
        isVp9,
        orElse: () => pool.firstWhere(isVp9, orElse: () => topCandidates.first),
      );
    }

    if (topHeight >= 1440) {
      return topCandidates.firstWhere(
        isVp9,
        orElse: () => topCandidates.firstWhere(
          isAv1,
          orElse: () => topCandidates.first,
        ),
      );
    }

    return topCandidates.firstWhere(
      isH264,
      orElse: () => topCandidates.firstWhere(
        isVp9,
        orElse: () => topCandidates.first,
      ),
    );
  }

  static String _readableVideoCodec(String raw) {
    final c = raw.toLowerCase();
    if (c.contains('avc')) return 'H.264';
    if (c.contains('vp09') || c.contains('vp9')) return 'VP9';
    if (c.contains('vp8')) return 'VP8';
    if (c.contains('av01')) return 'AV1';
    if (c.contains('hev') || c.contains('hvc')) return 'H.265';
    return raw.toUpperCase();
  }

  static String _audioTierLabel(int kbps, AudioFileFormat format) {
    if (kbps >= 180) return 'Máxima';
    if (kbps >= 110) return 'Alta';
    if (kbps >= 65) return 'Media';
    return 'Ligera';
  }

  static Exception _mapFriendlyException(Object e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('Error de red:') ||
          msg.contains('restricciones de edad') ||
          msg.contains('no está disponible') ||
          msg.contains('ha limitado las solicitudes') ||
          msg.contains('YouTube bloqueó') ||
          msg.contains('expiró')) {
        return e;
      }
    }
    final str = e.toString().toLowerCase();
    if (str.contains('failed host lookup') ||
        str.contains('socket') ||
        str.contains('network') ||
        str.contains('errno = 7') ||
        str.contains('connection refused') ||
        str.contains('handshake failed') ||
        str.contains('timed out')) {
      return Exception('Error de red: Comprueba tus datos móviles o Wi-Fi');
    }
    if (str.contains('unplayable') ||
        str.contains('age') ||
        str.contains('restricted') ||
        str.contains('login_required') ||
        str.contains('sign in') ||
        str.contains('transientfailure') ||
        str.contains('bot')) {
      return Exception(
        'El video tiene restricciones de edad o está bloqueado por YouTube',
      );
    }
    return Exception('No se pudo obtener la información del enlace: $e');
  }

  void close() {
    _yt.close();
    _httpClient.close();
  }
}

class _ManifestFetchResult {
  final StreamManifest manifest;
  final YoutubeApiClient client;
  const _ManifestFetchResult({required this.manifest, required this.client});
}

class _ParsedManifestOptions {
  final List<VideoQuality> availableQualities;
  final List<VideoStreamOption> videoOptions;
  final List<AudioStreamOption> audioOptions;
  final int? defaultAudioSizeBytes;
  final int? defaultVideoSizeBytes;

  const _ParsedManifestOptions({
    required this.availableQualities,
    required this.videoOptions,
    required this.audioOptions,
    this.defaultAudioSizeBytes,
    this.defaultVideoSizeBytes,
  });
}
