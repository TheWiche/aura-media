import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medias_download/core/services/settings_service.dart';
import 'package:medias_download/core/services/storage_service.dart';
import 'package:medias_download/core/services/task_persistence_service.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/features/downloader/data/models/media_metadata.dart';
import 'package:medias_download/features/share_modal/presentation/screens/share_modal_screen.dart';

class _FakeYoutubeExtractor extends YoutubeExtractor {
  final MediaMetadata metadata;
  _FakeYoutubeExtractor(this.metadata);

  @override
  Future<MediaMetadata> fetchMetadata(String url) async => metadata;

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService & Persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.initialize();
      await SettingsService.instance.reload();
    });

    test('Defaults prioritize Solo Audio and Share Modal', () {
      expect(SettingsService.instance.getDefaultMediaType(), MediaType.audio);
      expect(SettingsService.instance.getShareBehavior(), ShareBehavior.modal);
      expect(SettingsService.instance.getAutoCloseShareModal(), isTrue);
      expect(SettingsService.instance.getAudioFormat(), AudioFileFormat.mp3);
      expect(
        SettingsService.instance.getDuplicatePolicy(),
        DuplicateFilePolicy.rename,
      );
      expect(SettingsService.instance.getMaxConcurrentDownloads(), 2);
      expect(SettingsService.instance.getSaveDownloadHistory(), isTrue);
    });

    test('Stores separate audio & video paths, theme system, and extra prefs',
        () async {
      int notifications = 0;
      void listener() => notifications++;
      SettingsService.instance.changesNotifier.addListener(listener);

      await SettingsService.instance.setThemeMode(ThemeMode.system);
      expect(SettingsService.instance.getThemeMode(), ThemeMode.system);

      await SettingsService.instance.setAudioDownloadPath('/tmp/my_audio');
      await SettingsService.instance.setVideoDownloadPath('/tmp/my_video');
      expect(SettingsService.instance.getAudioDownloadPath(), '/tmp/my_audio');
      expect(SettingsService.instance.getVideoDownloadPath(), '/tmp/my_video');

      await SettingsService.instance.setAudioDownloadPath(null);
      expect(SettingsService.instance.getAudioDownloadPath(), isNull);

      await SettingsService.instance.setAudioFormat(AudioFileFormat.m4a);
      expect(SettingsService.instance.getAudioFormat(), AudioFileFormat.m4a);

      await SettingsService.instance
          .setDuplicatePolicy(DuplicateFilePolicy.overwrite);
      expect(
        SettingsService.instance.getDuplicatePolicy(),
        DuplicateFilePolicy.overwrite,
      );

      await SettingsService.instance.setIncludeAuthorInFilename(true);
      await SettingsService.instance.setScanMediaLibrary(false);
      await SettingsService.instance.setWifiOnly(true);
      await SettingsService.instance.setMaxConcurrentDownloads(99);
      await SettingsService.instance.setSaveDownloadHistory(false);

      expect(SettingsService.instance.getIncludeAuthorInFilename(), isTrue);
      expect(SettingsService.instance.getScanMediaLibrary(), isFalse);
      expect(SettingsService.instance.getWifiOnly(), isTrue);
      expect(SettingsService.instance.getMaxConcurrentDownloads(), 4);
      expect(SettingsService.instance.getSaveDownloadHistory(), isFalse);
      expect(notifications, greaterThanOrEqualTo(10));

      SettingsService.instance.changesNotifier.removeListener(listener);
    });

    test('DownloadTask JSON round-trip and TaskPersistenceService inbox',
        () async {
      final task = DownloadTask(
        id: 'task-abc',
        notificationId: 42,
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Test Audio',
        author: 'Artist',
        mediaType: MediaType.audio,
        quality: VideoQuality.best,
        fileExtension: 'mp3',
        totalBytes: 2048,
        downloadedBytes: 1024,
        status: DownloadStatus.downloading,
        createdAt: DateTime(2026, 11, 25, 10, 30),
      );

      final roundTrip = DownloadTask.fromJson(task.toJson());
      expect(roundTrip, equals(task));

      await TaskPersistenceService.instance.saveTasks([task]);
      final recovered = await TaskPersistenceService.instance.loadTasks(
        recoverInterrupted: true,
      );
      expect(recovered.length, 1);
      expect(recovered.first.status, DownloadStatus.queued);

      await TaskPersistenceService.instance.addPendingEnqueueTask(task);
      final pending =
          await TaskPersistenceService.instance.takePendingEnqueueTasks();
      expect(pending.length, 1);
      expect(pending.first.id, 'task-abc');

      final pendingAfterTake =
          await TaskPersistenceService.instance.takePendingEnqueueTasks();
      expect(pendingAfterTake, isEmpty);
    });
  });

  group('StorageService Separate Folders & Duplicate Policy', () {
    late Directory tempRoot;
    late Directory audioDir;
    late Directory videoDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.initialize();
      await SettingsService.instance.reload();

      tempRoot = await Directory.systemTemp.createTemp('aura_storage_test_');
      audioDir = Directory('${tempRoot.path}/Music');
      videoDir = Directory('${tempRoot.path}/Videos');
      await audioDir.create(recursive: true);
      await videoDir.create(recursive: true);

      await SettingsService.instance.setAudioDownloadPath(audioDir.path);
      await SettingsService.instance.setVideoDownloadPath(videoDir.path);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('Writes audio and video into distinct folders and renames duplicates',
        () async {
      final pathAudio1 = await StorageService.instance.getTargetPath(
        'Song.mp3',
        mediaType: MediaType.audio,
        duplicatePolicy: DuplicateFilePolicy.rename,
      );
      expect(pathAudio1, contains('Music'));

      await File(pathAudio1).writeAsString('data');

      final pathAudio2 = await StorageService.instance.getTargetPath(
        'Song.mp3',
        mediaType: MediaType.audio,
        duplicatePolicy: DuplicateFilePolicy.rename,
      );
      expect(pathAudio2, endsWith('Song (1).mp3'));

      final pathAudioOverwrite = await StorageService.instance.getTargetPath(
        'Song.mp3',
        mediaType: MediaType.audio,
        duplicatePolicy: DuplicateFilePolicy.overwrite,
      );
      expect(pathAudioOverwrite, equals(pathAudio1));

      final pathVideo = await StorageService.instance.getTargetPath(
        'Clip.mp4',
        mediaType: MediaType.video,
      );
      expect(pathVideo, contains('Videos'));
      expect(pathVideo, endsWith('Clip.mp4'));
    });
  });

  group('ShareModalScreen Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.initialize();
      await SettingsService.instance.reload();
    });

    testWidgets(
      'Defaults to Solo Audio and enqueues MP3 then closes on download',
      (WidgetTester tester) async {
        DownloadTask? enqueued;
        bool closed = false;

        final fakeMeta = const MediaMetadata(
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          title: 'Never Gonna Give You Up',
          author: 'Rick Astley',
          platform: 'YouTube',
          audioSizeBytes: 3500000,
          videoSizeBytes: 15000000,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShareModalScreen(
              initialSharedText: 'https://youtu.be/dQw4w9WgXcQ?si=share123',
              youtubeExtractor: _FakeYoutubeExtractor(fakeMeta),
              onEnqueueTask: (task) async {
                enqueued = task;
              },
              onClose: () {
                closed = true;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Never Gonna Give You Up'), findsOneWidget);
        expect(find.text('Solo Audio'), findsOneWidget);
        expect(find.text('Descargar Audio (MP3)'), findsOneWidget);

        await tester.tap(find.text('Descargar Audio (MP3)'));
        await tester.pumpAndSettle(const Duration(milliseconds: 600));

        expect(enqueued, isNotNull);
        expect(enqueued!.mediaType, MediaType.audio);
        expect(enqueued!.fileExtension, 'mp3');
        expect(enqueued!.title, 'Never Gonna Give You Up');
        expect(closed, isTrue);
      },
    );

    testWidgets(
      'Allows switching to Video and choosing 720p before downloading',
      (WidgetTester tester) async {
        DownloadTask? enqueued;

        final fakeMeta = const MediaMetadata(
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          title: 'Sample Video',
          author: 'Creator',
          platform: 'YouTube',
          audioSizeBytes: 2000000,
          videoSizeBytes: 24000000,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShareModalScreen(
              initialSharedText: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              youtubeExtractor: _FakeYoutubeExtractor(fakeMeta),
              onEnqueueTask: (task) async {
                enqueued = task;
              },
              onClose: () {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Video'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('720p'));
        await tester.pumpAndSettle();

        expect(find.text('Descargar Video (720p)'), findsOneWidget);

        await tester.tap(find.text('Descargar Video (720p)'));
        await tester.pumpAndSettle(const Duration(milliseconds: 600));

        expect(enqueued, isNotNull);
        expect(enqueued!.mediaType, MediaType.video);
        expect(enqueued!.quality, VideoQuality.p720);
        expect(enqueued!.fileExtension, 'mp4');
      },
    );
  });
}
