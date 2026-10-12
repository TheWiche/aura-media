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
  p1080,
  p720,
  p480,
  p360,
}

extension VideoQualityExtension on VideoQuality {
  String get label {
    switch (this) {
      case VideoQuality.best:
        return 'Mejor disponible';
      case VideoQuality.p1080:
        return '1080p Full HD';
      case VideoQuality.p720:
        return '720p HD';
      case VideoQuality.p480:
        return '480p SD';
      case VideoQuality.p360:
        return '360p';
    }
  }

  int? get heightPixels {
    switch (this) {
      case VideoQuality.best:
        return null;
      case VideoQuality.p1080:
        return 1080;
      case VideoQuality.p720:
        return 720;
      case VideoQuality.p480:
        return 480;
      case VideoQuality.p360:
        return 360;
    }
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
    String? savedPath,
    int? totalBytes,
    int? downloadedBytes,
    double? speedBytesPerSec,
    DownloadStatus? status,
    String? errorMessage,
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
      savedPath: savedPath ?? this.savedPath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
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

