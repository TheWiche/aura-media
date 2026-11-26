import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoQuality;
import '../../../../core/services/native_platform_service.dart';
import '../../../../core/services/settings_service.dart';
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
        _yt = yt ?? YoutubeExplode(httpClient: MobileYoutubeHttpClient());

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

      // Launch Stage 1A (oEmbed), Stage 1B (androidVr manifest) & Stage 2 (watch duration) in parallel!
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

      // Give oEmbed a brief moment only if snapshot still has placeholder title
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

      // Background Stage 2: finish awaiting watch details (duration) + complement streams only if needed
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

      // Let watch details finish if still pending (short bound)
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
      final manifestResult = await _getFastManifest(videoId);
      final manifest = manifestResult.manifest;
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
              // DASH mp4 audio streams use `moof` fragments; remuxing via MediaExtractor/MediaMuxer
              // turns them into clean single-`moov` seekable `.m4a` or `.mp3` files.
              requiresAudioExtraction: !isWebm,
              requiresVideoAudioMux: false,
            );
          }
        }

        // Legacy/resilience fallback: download muxed itag 18 and strip video track natively
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
      // 1. Exact video itag requested by user from progressive options UI
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

      // 2. Match by quality + container preference
      if (!forceMuxedFallback && manifest.videoOnly.isNotEmpty) {
        final bestVideoOnly = _pickVideoOnlyStream(
          manifest,
          quality: quality,
          preference: preferredVideoFormat,
          allowAv1InMp4: sdkInt >= 29,
        );

        if (bestVideoOnly != null) {
          // Prefer muxed 360p directly ONLY if user explicitly asked for 360p MP4
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

      // 3. Fallback to muxed (360p direct)
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
    final container = video.container.name.toLowerCase(); // 'mp4' or 'webm'
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

    if (audio == null) {
      // Last-resort fallback to any audioOnly or muxed
      if (manifest.audioOnly.isNotEmpty) {
        audio = manifest.audioOnly.withHighestBitrate();
      }
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

  Future<_ManifestFetchResult> _getFastManifest(VideoId videoId) async {
    // Try fastest, 403-free Innertube client first (`androidVr` ~300 ms)
    for (final client in const [
      YoutubeApiClient.androidVr,
      YoutubeApiClient.androidSdkless,
      YoutubeApiClient.tv,
    ]) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [client],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 10));
        if (manifest.streams.isNotEmpty) {
          return _ManifestFetchResult(manifest: manifest, client: client);
        }
      } catch (e) {
        if (client == YoutubeApiClient.tv) rethrow;
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

    // Filter reliable audio tracks (exclude problematic surround EC-3/AC-3/258 for primary playback compatibility)
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

    // ─── Build Detailed Audio Options ────────────────────────────────────────
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

    // ─── Build Detailed Video Options ────────────────────────────────────────
    final videoOptions = <VideoStreamOption>[];
    final seenVideoKeys = <String>{};

    // Sort adaptive video streams from highest resolution + fps + bitrate
    final sortedVideoOnly = manifest.videoOnly.sortByVideoQuality();
    for (final v in sortedVideoOnly) {
      final container = v.container.name.toLowerCase();
      final rawCodec = v.videoCodec.toLowerCase();
      final readableCodec = _readableVideoCodec(rawCodec);

      if (readableCodec == 'AV1' && !allowAv1InMp4 && container == 'mp4') {
        continue;
      }

      // Skip odd codecs we can't cleanly mux on Android
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

    // Add direct muxed options (e.g., itag 18 360p fast zero-mux download)
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

    // Order by height desc, then H.264/MP4 before VP9 before AV1, then FPS desc
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

    // Group at top matching height
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
          orElse: () => pool.firstWhere(isH264, orElse: () => topCandidates.first),
        ),
      );
    }

    if (preference == VideoFormatPreference.webm) {
      return topCandidates.firstWhere(
        isVp9,
        orElse: () => pool.firstWhere(isVp9, orElse: () => topCandidates.first),
      );
    }

    // Auto: H.264 for <= 1080p, VP9 for 1440p/4K
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
          msg.contains('ha limitado las solicitudes')) {
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
