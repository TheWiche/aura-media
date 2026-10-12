import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoQuality;
import '../models/download_task.dart';
import '../models/media_metadata.dart';

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

  YoutubeExtractor({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  /// Check if the URL is a recognized YouTube URL
  static bool isYoutubeUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('music.youtube.com');
  }

  /// Extract metadata and video details from YouTube
  Future<MediaMetadata> fetchMetadata(String url) async {
    final videoId = VideoId(url.trim());
    final video = await _yt.videos.get(videoId);

    // Get available stream qualities
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
      url: url.trim(),
      title: video.title,
      author: video.author,
      thumbnailUrl: video.thumbnails.highResUrl.isNotEmpty
          ? video.thumbnails.highResUrl
          : video.thumbnails.mediumResUrl,
      duration: video.duration,
      platform: 'YouTube',
      availableQualities: availableQualities.toList(),
    );
  }

  /// Resolve the stream and return a stream reader with total bytes
  Future<ResolvedStream> resolveStream({
    required String url,
    required MediaType mediaType,
    VideoQuality quality = VideoQuality.best,
  }) async {
    final videoId = VideoId(url.trim());
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);

    if (mediaType == MediaType.audio) {
      // Pick best audio-only stream (m4a/mp4 container preferred for mobile playback)
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
        extension: bestAudio.container.name.toLowerCase() == 'webm' ? 'm4a' : bestAudio.container.name.toLowerCase(),
      );
    } else {
      // For video: prefer muxed streams (contains both video and audio out-of-the-box)
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      if (muxedStreams.isEmpty) {
        // Fallback to video-only if no muxed stream is present
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
        selectedStream = muxedStreams.first; // highest quality muxed stream
      } else {
        // Find closest muxed stream matching desired resolution
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
  }

  void close() {
    _yt.close();
  }
}

