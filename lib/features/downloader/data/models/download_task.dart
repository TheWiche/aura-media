import 'package:equatable/equatable.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

enum MediaType {
  audio,
  video,
}

enum VideoQuality {
  best,
  p2160,
  p1440,
  p1080,
  p720,
  p480,
  p360,
  p240,
  p144,
}

extension VideoQualityExtension on VideoQuality {
  String get label {
    switch (this) {
      case VideoQuality.best:
        return 'Mejor disponible';
      case VideoQuality.p2160:
        return '4K · 2160p';
      case VideoQuality.p1440:
        return '2K · 1440p';
      case VideoQuality.p1080:
        return '1080p Full HD';
      case VideoQuality.p720:
        return '720p HD';
      case VideoQuality.p480:
        return '480p SD';
      case VideoQuality.p360:
        return '360p';
      case VideoQuality.p240:
        return '240p';
      case VideoQuality.p144:
        return '144p';
    }
  }

  String get shortLabel {
    switch (this) {
      case VideoQuality.best:
        return 'Mejor';
      case VideoQuality.p2160:
        return '4K';
      case VideoQuality.p1440:
        return '2K';
      case VideoQuality.p1080:
        return '1080p';
      case VideoQuality.p720:
        return '720p';
      case VideoQuality.p480:
        return '480p';
      case VideoQuality.p360:
        return '360p';
      case VideoQuality.p240:
        return '240p';
      case VideoQuality.p144:
        return '144p';
    }
  }

  int? get heightPixels {
    switch (this) {
      case VideoQuality.best:
        return null;
      case VideoQuality.p2160:
        return 2160;
      case VideoQuality.p1440:
        return 1440;
      case VideoQuality.p1080:
        return 1080;
      case VideoQuality.p720:
        return 720;
      case VideoQuality.p480:
        return 480;
      case VideoQuality.p360:
        return 360;
      case VideoQuality.p240:
        return 240;
      case VideoQuality.p144:
        return 144;
    }
  }

  static VideoQuality fromHeight(int height) {
    if (height >= 2000) return VideoQuality.p2160;
    if (height >= 1350) return VideoQuality.p1440;
    if (height >= 1000) return VideoQuality.p1080;
    if (height >= 680) return VideoQuality.p720;
    if (height >= 440) return VideoQuality.p480;
    if (height >= 330) return VideoQuality.p360;
    if (height >= 210) return VideoQuality.p240;
    return VideoQuality.p144;
  }
}

class DownloadTask extends Equatable {
  final String id;
  final int notificationId;
  final String url;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final MediaType mediaType;
  final VideoQuality quality;
  final String fileExtension;
  final int? videoItag;
  final int? audioItag;
  final String? audioLanguage;
  final String? specSummary;
  final String? savedPath;
  final int totalBytes;
  final int downloadedBytes;
  final double speedBytesPerSec;
  final DownloadStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.notificationId,
    required this.url,
    required this.title,
    this.author,
    this.thumbnailUrl,
    required this.mediaType,
    this.quality = VideoQuality.best,
    required this.fileExtension,
    this.videoItag,
    this.audioItag,
    this.audioLanguage,
    this.specSummary,
    this.savedPath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.status = DownloadStatus.queued,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).toInt();

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  bool get isPaused => status == DownloadStatus.paused;

  bool get isTerminal =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.failed ||
      status == DownloadStatus.canceled;

  bool get isCompleted => status == DownloadStatus.completed;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notificationId': notificationId,
      'url': url,
      'title': title,
      'author': author,
      'thumbnailUrl': thumbnailUrl,
      'mediaType': mediaType.name,
      'quality': quality.name,
      'fileExtension': fileExtension,
      'videoItag': videoItag,
      'audioItag': audioItag,
      'audioLanguage': audioLanguage,
      'specSummary': specSummary,
      'savedPath': savedPath,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'speedBytesPerSec': speedBytesPerSec,
      'status': status.name,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      notificationId: (json['notificationId'] as num).toInt(),
      url: json['url'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mediaType: MediaType.values.firstWhere(
        (e) => e.name == json['mediaType'],
        orElse: () => MediaType.audio,
      ),
      quality: VideoQuality.values.firstWhere(
        (e) => e.name == json['quality'],
        orElse: () => VideoQuality.best,
      ),
      fileExtension: json['fileExtension'] as String? ?? 'mp3',
      videoItag: (json['videoItag'] as num?)?.toInt(),
      audioItag: (json['audioItag'] as num?)?.toInt(),
      audioLanguage: json['audioLanguage'] as String?,
      specSummary: json['specSummary'] as String?,
      savedPath: json['savedPath'] as String?,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      speedBytesPerSec: (json['speedBytesPerSec'] as num?)?.toDouble() ?? 0.0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  DownloadTask copyWith({
    String? id,
    int? notificationId,
    String? url,
    String? title,
    String? author,
    String? thumbnailUrl,
    MediaType? mediaType,
    VideoQuality? quality,
    String? fileExtension,
    int? videoItag,
    int? audioItag,
    String? audioLanguage,
    String? specSummary,
    String? savedPath,
    int? totalBytes,
    int? downloadedBytes,
    double? speedBytesPerSec,
    DownloadStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      url: url ?? this.url,
      title: title ?? this.title,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaType: mediaType ?? this.mediaType,
      quality: quality ?? this.quality,
      fileExtension: fileExtension ?? this.fileExtension,
      videoItag: videoItag ?? this.videoItag,
      audioItag: audioItag ?? this.audioItag,
      audioLanguage: audioLanguage ?? this.audioLanguage,
      specSummary: specSummary ?? this.specSummary,
      savedPath: savedPath ?? this.savedPath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      status: status ?? this.status,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        notificationId,
        url,
        title,
        author,
        thumbnailUrl,
        mediaType,
        quality,
        fileExtension,
        videoItag,
        audioItag,
        audioLanguage,
        specSummary,
        savedPath,
        totalBytes,
        downloadedBytes,
        speedBytesPerSec,
        status,
        errorMessage,
        createdAt,
        completedAt,
      ];
}
