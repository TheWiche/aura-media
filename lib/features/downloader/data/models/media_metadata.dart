import 'package:equatable/equatable.dart';
import 'download_task.dart';

class MediaMetadata extends Equatable {
  final String url;
  final String title;
  final String author;
  final String? thumbnailUrl;
  final Duration? duration;
  final String platform;
  final List<VideoQuality> availableQualities;
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
    this.directDownloadUrl,
    this.audioSizeBytes,
    this.videoSizeBytes,
  });

  @override
  List<Object?> get props => [
        url,
        title,
        author,
        thumbnailUrl,
        duration,
        platform,
        availableQualities,
        directDownloadUrl,
        audioSizeBytes,
        videoSizeBytes,
      ];
}

