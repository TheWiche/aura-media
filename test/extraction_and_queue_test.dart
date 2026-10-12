import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:medias_download/core/utils/formatters.dart';
import 'package:medias_download/features/downloader/data/datasources/generic_extractor.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/features/downloader/domain/queue/download_queue_manager.dart';

void main() {
  group('1. URL Detection & Extraction Utilities Test', () {
    test('YouTube URL detection matches valid links', () {
      expect(YoutubeExtractor.isYoutubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(YoutubeExtractor.isYoutubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(YoutubeExtractor.isYoutubeUrl('https://music.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(YoutubeExtractor.isYoutubeUrl('https://vimeo.com/123456'), isFalse);
      expect(YoutubeExtractor.isYoutubeUrl('https://tiktok.com/@user/video/123'), isFalse);
    });

    test('GenericExtractor detects third-party platforms', () {
      expect(GenericExtractor.detectPlatform('https://www.tiktok.com/@user/video/123'), 'TikTok');
      expect(GenericExtractor.detectPlatform('https://www.instagram.com/reel/C123'), 'Instagram');
      expect(GenericExtractor.detectPlatform('https://x.com/user/status/123'), 'Twitter / X');
      expect(GenericExtractor.detectPlatform('https://twitter.com/user/status/123'), 'Twitter / X');
      expect(GenericExtractor.detectPlatform('https://www.facebook.com/watch/?v=123'), 'Facebook');
      expect(GenericExtractor.detectPlatform('https://example.com/video.mp4'), 'Web Directo');
    });

    test('Formatters calculate bytes, speeds and durations properly', () {
      expect(Formatters.formatBytes(0), '0 B');
      expect(Formatters.formatBytes(1024), '1.0 KB');
      expect(Formatters.formatBytes(1048576 * 15), '15.0 MB');
      expect(Formatters.formatSpeed(1048576 * 2.5), '2.50 MB/s');
      expect(Formatters.formatDuration(const Duration(minutes: 3, seconds: 45)), '03:45');
      expect(Formatters.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
      expect(Formatters.sanitizeFileName('video: test/name?*<>.mp4'), 'video_ test_name____.mp4');
    });
  });

  group('2. DownloadTask Lifecycle & State Machine Test', () {
    test('Task correctly computes progress and terminal states', () {
      final task = DownloadTask(
        id: 'test-uuid-1',
        notificationId: 101,
        url: 'https://youtube.com/watch?v=sample',
        title: 'Sample Video',
        mediaType: MediaType.video,
        quality: VideoQuality.p1080,
        fileExtension: 'mp4',
        createdAt: DateTime.now(),
        totalBytes: 1000,
        downloadedBytes: 450,
        status: DownloadStatus.downloading,
      );

      expect(task.progress, 0.45);
      expect(task.progressPercent, 45);
      expect(task.isActive, isTrue);
      expect(task.isTerminal, isFalse);

      final completedTask = task.copyWith(
        status: DownloadStatus.completed,
        downloadedBytes: 1000,
      );
      expect(completedTask.progress, 1.0);
      expect(completedTask.progressPercent, 100);
      expect(completedTask.isCompleted, isTrue);
      expect(completedTask.isTerminal, isTrue);
    });
  });

  group('3. DownloadQueueManager Concurrency & Event Stream Test', () {
    late DownloadQueueManager queueManager;

    setUp(() {
      queueManager = DownloadQueueManager.instance;
      queueManager.setMaxConcurrency(2);
    });

    test('Adding tasks triggers stream update and observes concurrency limit', () async {
      final completer = Completer<List<DownloadTask>>();

      final subscription = queueManager.tasksStream.listen((tasks) {
        if (tasks.isNotEmpty && !completer.isCompleted) {
          completer.complete(tasks);
        }
      });

      final task1 = DownloadTask(
        id: 'mock-task-1',
        notificationId: 1001,
        url: 'https://example.com/file1.mp4',
        title: 'Mock Task 1',
        mediaType: MediaType.video,
        fileExtension: 'mp4',
        createdAt: DateTime.now(),
      );

      queueManager.addTask(task1);

      final emittedTasks = await completer.future.timeout(const Duration(seconds: 3));
      expect(emittedTasks.any((t) => t.id == 'mock-task-1'), isTrue);

      // Verify pause and resume lifecycle
      await queueManager.pauseTask('mock-task-1');
      expect(queueManager.currentTasks.firstWhere((t) => t.id == 'mock-task-1').status, DownloadStatus.paused);

      queueManager.resumeTask('mock-task-1');
      expect(queueManager.currentTasks.firstWhere((t) => t.id == 'mock-task-1').isActive, isTrue);

      // Verify cancel lifecycle
      await queueManager.cancelTask('mock-task-1');
      expect(queueManager.currentTasks.firstWhere((t) => t.id == 'mock-task-1').status, DownloadStatus.canceled);

      // Verify remove
      await queueManager.removeTask('mock-task-1');
      expect(queueManager.currentTasks.any((t) => t.id == 'mock-task-1'), isFalse);

      await subscription.cancel();
    });
  });
}
