import 'package:equatable/equatable.dart';
import '../../../../core/services/settings_service.dart';
import 'download_task.dart';

/// Progressive stages during link analysis so UI renders instantaneously
/// and refines formats/details behind the scenes.
enum AnalysisStage {
  instant,
  basicInfo,
  streamsReady,
  enriching,
  complete,
}

extension AnalysisStageExtension on AnalysisStage {
  bool get hasBasicInfo => index >= AnalysisStage.basicInfo.index;
  bool get hasStreams => index >= AnalysisStage.streamsReady.index;
  bool get isComplete => this == AnalysisStage.complete;
}

class VideoStreamOption extends Equatable {
  final String id;
  final VideoQuality quality;
  final int height;
  final int width;
  final int fps;
  final String container; // 'mp4' or 'webm'
  final String videoCodec; // 'H.264', 'VP9', 'AV1'
  final String rawVideoCodec;
  final String audioCodec; // 'AAC', 'Opus'
  final int videoItag;
  final int? audioItag;
  final bool isMuxed;
  final bool isHdr;
  final int videoSizeBytes;
  final int audioSizeBytes;
  final int bitrateKbps;
  final String compatibilityNote;

  const VideoStreamOption({
    required this.id,
    required this.quality,
    required this.height,
    required this.width,
    required this.fps,
    required this.container,
    required this.videoCodec,
    required this.rawVideoCodec,
    required this.audioCodec,
    required this.videoItag,
    this.audioItag,
    this.isMuxed = false,
    this.isHdr = false,
    required this.videoSizeBytes,
    this.audioSizeBytes = 0,
    this.bitrateKbps = 0,
    this.compatibilityNote = '',
  });

  int get totalSizeBytes => videoSizeBytes + audioSizeBytes;

  String get resolutionTag =>
      fps >= 48 ? '${quality.shortLabel}$fps' : quality.shortLabel;

  String get formatBadge => '${container.toUpperCase()} · $videoCodec';

  String get specSummary {
    final fpsPart = fps >= 48 ? '${fps}fps · ' : '';
    final hdrPart = isHdr ? 'HDR · ' : '';
    return '${quality.shortLabel} · $fpsPart$hdrPart${container.toUpperCase()} ($videoCodec + $audioCodec)';
  }

  @override
  List<Object?> get props => [
        id,
        quality,
        height,
        width,
        fps,
        container,
        videoCodec,
        rawVideoCodec,
        audioCodec,
        videoItag,
        audioItag,
        isMuxed,
        isHdr,
        videoSizeBytes,
        audioSizeBytes,
        bitrateKbps,
        compatibilityNote,
      ];
}

class AudioStreamOption extends Equatable {
  final String id;
  final AudioFileFormat format;
  final String extension; // 'mp3', 'm4a', 'webm'
  final String codecLabel; // 'AAC-LC', 'HE-AAC', 'Opus', 'AAC → MP3'
  final int bitrateKbps;
  final String qualityTier; // 'Máxima', 'Alta', 'Media', 'Ligera'
  final int sizeBytes;
  final int itag;
  final String? trackLanguage;
  final bool isDefaultTrack;
  final String note;

  const AudioStreamOption({
    required this.id,
    required this.format,
    required this.extension,
    required this.codecLabel,
    required this.bitrateKbps,
    required this.qualityTier,
    required this.sizeBytes,
    required this.itag,
    this.trackLanguage,
    this.isDefaultTrack = true,
    this.note = '',
  });

  String get specSummary {
    final kbpsPart = bitrateKbps > 0 ? '$bitrateKbps kbps · ' : '';
    return '${extension.toUpperCase()} · $qualityTier ($kbpsPart$codecLabel)';
  }

  @override
  List<Object?> get props => [
        id,
        format,
        extension,
        codecLabel,
        bitrateKbps,
        qualityTier,
        sizeBytes,
        itag,
        trackLanguage,
        isDefaultTrack,
        note,
      ];
}

class MediaMetadata extends Equatable {
  final String url;
  final String title;
  final String author;
  final String? thumbnailUrl;
  final Duration? duration;
  final String platform;
  final List<VideoQuality> availableQualities;
  final List<VideoStreamOption> videoOptions;
  final List<AudioStreamOption> audioOptions;
  final AnalysisStage analysisStage;
  final String? directDownloadUrl;
  final int? audioSizeBytes;
  final int? videoSizeBytes;

  const MediaMetadata({
    required this.url,
    required this.title,
    required this.author,
    this.thumbnailUrl,
    this.duration,
    required this.platform,
    this.availableQualities = const [
      VideoQuality.best,
      VideoQuality.p1080,
      VideoQuality.p720,
      VideoQuality.p480,
      VideoQuality.p360,
    ],
    this.videoOptions = const [],
    this.audioOptions = const [],
    this.analysisStage = AnalysisStage.complete,
    this.directDownloadUrl,
    this.audioSizeBytes,
    this.videoSizeBytes,
  });

  MediaMetadata copyWith({
    String? url,
    String? title,
    String? author,
    String? thumbnailUrl,
    Duration? duration,
    String? platform,
    List<VideoQuality>? availableQualities,
    List<VideoStreamOption>? videoOptions,
    List<AudioStreamOption>? audioOptions,
    AnalysisStage? analysisStage,
    String? directDownloadUrl,
    int? audioSizeBytes,
    int? videoSizeBytes,
  }) {
    return MediaMetadata(
      url: url ?? this.url,
      title: title ?? this.title,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      platform: platform ?? this.platform,
      availableQualities: availableQualities ?? this.availableQualities,
      videoOptions: videoOptions ?? this.videoOptions,
      audioOptions: audioOptions ?? this.audioOptions,
      analysisStage: analysisStage ?? this.analysisStage,
      directDownloadUrl: directDownloadUrl ?? this.directDownloadUrl,
      audioSizeBytes: audioSizeBytes ?? this.audioSizeBytes,
      videoSizeBytes: videoSizeBytes ?? this.videoSizeBytes,
    );
  }

  /// Helper returning distinct audio tracks/languages when video has dubs.
  List<String> get availableAudioLanguages {
    final seen = <String>[];
    for (final opt in audioOptions) {
      final lang = opt.trackLanguage?.trim();
      if (lang != null && lang.isNotEmpty && !seen.contains(lang)) {
        seen.add(lang);
      }
    }
    return seen;
  }

  /// Video options matching [quality] (or highest available height when [VideoQuality.best]).
  List<VideoStreamOption> matchingVideoOptions(VideoQuality quality) {
    if (videoOptions.isEmpty) return const [];
    if (quality == VideoQuality.best) {
      final topHeight = videoOptions.first.height;
      return videoOptions.where((o) => o.height == topHeight).toList();
    }
    final exact = videoOptions.where((o) => o.quality == quality).toList();
    if (exact.isNotEmpty) return exact;

    final targetH = quality.heightPixels;
    if (targetH != null) {
      final lower = videoOptions.where((o) => o.height <= targetH).toList();
      if (lower.isNotEmpty) {
        final bestH = lower.first.height;
        return lower.where((o) => o.height == bestH).toList();
      }
    }
    final topHeight = videoOptions.first.height;
    return videoOptions.where((o) => o.height == topHeight).toList();
  }

  VideoStreamOption? bestVideoOptionFor(
    VideoQuality quality,
    VideoFormatPreference formatPref,
  ) {
    final candidates = matchingVideoOptions(quality);
    if (candidates.isEmpty) return null;

    if (formatPref == VideoFormatPreference.mp4) {
      return candidates.firstWhere(
        (o) => o.container == 'mp4',
        orElse: () => candidates.first,
      );
    }
    if (formatPref == VideoFormatPreference.webm) {
      return candidates.firstWhere(
        (o) => o.container == 'webm',
        orElse: () => candidates.first,
      );
    }
    // Auto: H.264/MP4 up to 1080p, VP9/WebM for 1440p+
    final topHeight = candidates.first.height;
    if (topHeight >= 1440) {
      return candidates.firstWhere(
        (o) => o.container == 'webm' && o.videoCodec == 'VP9',
        orElse: () => candidates.first,
      );
    }
    return candidates.firstWhere(
      (o) => o.container == 'mp4' && o.videoCodec.contains('H.264'),
      orElse: () => candidates.first,
    );
  }

  List<AudioStreamOption> matchingAudioOptions(AudioFileFormat format) {
    return audioOptions.where((o) => o.format == format).toList();
  }

  AudioStreamOption? bestAudioOptionFor(AudioFileFormat format) {
    final pool = matchingAudioOptions(format);
    if (pool.isEmpty) return null;
    // Prefer standard high bitrate (~128-160 kbps) default track
    final defaults = pool.where((o) => o.isDefaultTrack).toList();
    final activePool = defaults.isNotEmpty ? defaults : pool;
    final highStandard = activePool.where(
      (o) => o.bitrateKbps >= 110 && o.bitrateKbps <= 192,
    );
    if (highStandard.isNotEmpty) return highStandard.first;
    return activePool.first;
  }

  @override
  List<Object?> get props => [
        url,
        title,
        author,
        thumbnailUrl,
        duration,
        platform,
        availableQualities,
        videoOptions,
        audioOptions,
        analysisStage,
        directDownloadUrl,
        audioSizeBytes,
        videoSizeBytes,
      ];
}
