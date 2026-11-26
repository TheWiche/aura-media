import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medias_download/core/services/settings_service.dart';
import 'package:medias_download/core/theme/aura_theme.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/features/downloader/data/models/media_metadata.dart';
import 'package:medias_download/features/share_modal/presentation/screens/share_modal_screen.dart';
import 'package:medias_download/shared/widgets/aura_format_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StagedYoutubeExtractor extends YoutubeExtractor {
  final Duration stepDelay;
  _StagedYoutubeExtractor({this.stepDelay = const Duration(milliseconds: 25)});

  @override
  Future<MediaMetadata> fetchMetadataProgressive(
    String url, {
    required void Function(MediaMetadata partial) onProgress,
  }) async {
    var current = MediaMetadata(
      url: url,
      title: 'Cargando video de YouTube...',
      author: 'YouTube',
      platform: 'YouTube',
      availableQualities: const [VideoQuality.best],
      analysisStage: AnalysisStage.instant,
    );
    onProgress(current);

    await Future.delayed(stepDelay);
    current = current.copyWith(
      title: 'Blender 4K Demo',
      author: 'Blender Studio',
      analysisStage: AnalysisStage.basicInfo,
    );
    onProgress(current);

    await Future.delayed(stepDelay);
    const v4k = VideoStreamOption(
      id: '315+251',
      quality: VideoQuality.p2160,
      height: 2160,
      width: 3840,
      fps: 60,
      container: 'webm',
      videoCodec: 'VP9',
      rawVideoCodec: 'vp9',
      audioCodec: 'Opus',
      videoItag: 315,
      audioItag: 251,
      videoSizeBytes: 500 * 1024 * 1024,
      audioSizeBytes: 5 * 1024 * 1024,
      compatibilityNote: 'Ultra HD hasta 4K · WebM nativo',
    );
    const v1080Mp4 = VideoStreamOption(
      id: '299+140',
      quality: VideoQuality.p1080,
      height: 1080,
      width: 1920,
      fps: 60,
      container: 'mp4',
      videoCodec: 'H.264',
      rawVideoCodec: 'avc1.64002a',
      audioCodec: 'AAC',
      videoItag: 299,
      audioItag: 140,
      videoSizeBytes: 120 * 1024 * 1024,
      audioSizeBytes: 4 * 1024 * 1024,
      compatibilityNote: 'Máxima compatibilidad',
    );
    const aM4a = AudioStreamOption(
      id: 'm4a_140',
      format: AudioFileFormat.m4a,
      extension: 'm4a',
      codecLabel: 'AAC-LC',
      bitrateKbps: 128,
      qualityTier: 'Alta',
      sizeBytes: 4 * 1024 * 1024,
      itag: 140,
      note: 'Nativo iOS/Android',
    );
    const aOpus = AudioStreamOption(
      id: 'webm_251',
      format: AudioFileFormat.webm,
      extension: 'webm',
      codecLabel: 'Opus WebM',
      bitrateKbps: 140,
      qualityTier: 'Alta',
      sizeBytes: 3800 * 1024,
      itag: 251,
      note: 'Máx. fidelidad por MB',
    );

    current = current.copyWith(
      availableQualities: const [
        VideoQuality.best,
        VideoQuality.p2160,
        VideoQuality.p1080,
      ],
      videoOptions: const [v4k, v1080Mp4],
      audioOptions: const [aM4a, aOpus],
      audioSizeBytes: aM4a.sizeBytes,
      videoSizeBytes: v4k.totalSizeBytes,
      analysisStage: AnalysisStage.streamsReady,
    );
    onProgress(current);

    await Future.delayed(stepDelay);
    current = current.copyWith(
      duration: const Duration(minutes: 4, seconds: 20),
      analysisStage: AnalysisStage.complete,
    );
    onProgress(current);
    return current;
  }

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Quality, Codecs & Progressive Analysis', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.initialize();
      await SettingsService.instance.reload();
    });

    test('SettingsService stores extended VideoQuality, VideoFormat & Opus audio',
        () async {
      await SettingsService.instance.setDefaultQuality(VideoQuality.p2160);
      await SettingsService.instance
          .setDefaultVideoFormat(VideoFormatPreference.webm);
      await SettingsService.instance.setAudioFormat(AudioFileFormat.webm);

      expect(SettingsService.instance.getDefaultQuality(), VideoQuality.p2160);
      expect(
        SettingsService.instance.getDefaultVideoFormat(),
        VideoFormatPreference.webm,
      );
      expect(SettingsService.instance.getAudioFormat(), AudioFileFormat.webm);
    });

    test('DownloadTask preserves extended itag, codec summary & 4K quality in JSON',
        () {
      final task = DownloadTask(
        id: 'vid-4k-1',
        notificationId: 99,
        url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
        title: 'Big Buck Bunny',
        mediaType: MediaType.video,
        quality: VideoQuality.p2160,
        fileExtension: 'webm',
        videoItag: 315,
        audioItag: 251,
        audioLanguage: 'English',
        specSummary: '4K · 60fps · WEBM (VP9 + Opus)',
        totalBytes: 1300000000,
        createdAt: DateTime(2026, 11, 26),
      );

      final roundTrip = DownloadTask.fromJson(task.toJson());
      expect(roundTrip, equals(task));
      expect(roundTrip.quality, VideoQuality.p2160);
      expect(roundTrip.videoItag, 315);
      expect(roundTrip.audioItag, 251);
      expect(roundTrip.audioLanguage, 'English');
      expect(roundTrip.specSummary, '4K · 60fps · WEBM (VP9 + Opus)');
    });

    test('MediaMetadata picks optimal video codec and audio option per preference',
        () {
      const meta = MediaMetadata(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Test',
        author: 'Creator',
        platform: 'YouTube',
        availableQualities: [
          VideoQuality.best,
          VideoQuality.p2160,
          VideoQuality.p1080,
        ],
        videoOptions: [
          VideoStreamOption(
            id: '313+251',
            quality: VideoQuality.p2160,
            height: 2160,
            width: 3840,
            fps: 30,
            container: 'webm',
            videoCodec: 'VP9',
            rawVideoCodec: 'vp9',
            audioCodec: 'Opus',
            videoItag: 313,
            audioItag: 251,
            videoSizeBytes: 340000000,
            audioSizeBytes: 3400000,
          ),
          VideoStreamOption(
            id: '137+140',
            quality: VideoQuality.p1080,
            height: 1080,
            width: 1920,
            fps: 30,
            container: 'mp4',
            videoCodec: 'H.264',
            rawVideoCodec: 'avc1',
            audioCodec: 'AAC',
            videoItag: 137,
            audioItag: 140,
            videoSizeBytes: 77000000,
            audioSizeBytes: 3400000,
          ),
          VideoStreamOption(
            id: '248+251',
            quality: VideoQuality.p1080,
            height: 1080,
            width: 1920,
            fps: 30,
            container: 'webm',
            videoCodec: 'VP9',
            rawVideoCodec: 'vp9',
            audioCodec: 'Opus',
            videoItag: 248,
            audioItag: 251,
            videoSizeBytes: 29000000,
            audioSizeBytes: 3400000,
          ),
        ],
        audioOptions: [
          AudioStreamOption(
            id: 'm4a_140',
            format: AudioFileFormat.m4a,
            extension: 'm4a',
            codecLabel: 'AAC-LC',
            bitrateKbps: 128,
            qualityTier: 'Alta',
            sizeBytes: 3400000,
            itag: 140,
          ),
          AudioStreamOption(
            id: 'webm_251',
            format: AudioFileFormat.webm,
            extension: 'webm',
            codecLabel: 'Opus WebM',
            bitrateKbps: 133,
            qualityTier: 'Alta',
            sizeBytes: 3300000,
            itag: 251,
          ),
        ],
      );

      final auto1080 =
          meta.bestVideoOptionFor(VideoQuality.p1080, VideoFormatPreference.auto);
      expect(auto1080?.videoItag, 137);

      final webm1080 =
          meta.bestVideoOptionFor(VideoQuality.p1080, VideoFormatPreference.webm);
      expect(webm1080?.videoItag, 248);

      final auto4k =
          meta.bestVideoOptionFor(VideoQuality.p2160, VideoFormatPreference.auto);
      expect(auto4k?.videoItag, 313);
      expect(auto4k?.container, 'webm');

      expect(meta.bestAudioOptionFor(AudioFileFormat.webm)?.itag, 251);
      expect(meta.bestAudioOptionFor(AudioFileFormat.m4a)?.itag, 140);
    });

    testWidgets(
        'ShareModalScreen updates UI progressively from instant to streamsReady to complete',
        (tester) async {
      DownloadTask? enqueued;
      final extractor = _StagedYoutubeExtractor(
        stepDelay: const Duration(milliseconds: 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.dark,
          home: ShareModalScreen(
            initialSharedText: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
            youtubeExtractor: extractor,
            onEnqueueTask: (t) async => enqueued = t,
            onClose: () {},
          ),
        ),
      );

      // Stage 0 instant: immediate preview visible
      await tester.pump();
      expect(find.text('Cargando video de YouTube...'), findsOneWidget);

      // Stage 1A basicInfo: real title arrives quickly
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Blender 4K Demo'), findsOneWidget);

      // Stage 1B streamsReady + complete: resolutions & formats appear
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(find.text('04:20'), findsOneWidget);

      // Switch to OPUS and download
      await tester.ensureVisible(find.text('OPUS'));
      await tester.tap(find.text('OPUS'));
      await tester.pumpAndSettle();
      expect(find.text('Alta · 140k'), findsOneWidget);
      expect(find.textContaining('Opus WebM · 3.7 MB'), findsOneWidget);

      // Switch to Video -> pick 4K -> download exact itag 315+251
      await tester.ensureVisible(find.text('Video'));
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      expect(find.text('4K'), findsOneWidget);
      await tester.ensureVisible(find.text('4K'));
      await tester.tap(find.text('4K'));
      await tester.pumpAndSettle();

      expect(find.textContaining('WEBM · VP9 + Opus'), findsOneWidget);
      await tester.tap(find.textContaining('Descargar Video'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(enqueued, isNotNull);
      expect(enqueued!.quality, VideoQuality.p2160);
      expect(enqueued!.videoItag, 315);
      expect(enqueued!.audioItag, 251);
      expect(enqueued!.fileExtension, 'webm');
    });
  });

  group('AuraFormatSelector Multi-Format UI', () {
    testWidgets('Renders Audio formats & bitrates and Video resolutions & codecs',
        (tester) async {
      MediaType mediaType = MediaType.audio;
      VideoQuality quality = VideoQuality.p1080;
      AudioFileFormat audioFormat = AudioFileFormat.m4a;
      VideoStreamOption? selectedVideo;
      AudioStreamOption? selectedAudio;

      const v1080Mp4 = VideoStreamOption(
        id: '137+140',
        quality: VideoQuality.p1080,
        height: 1080,
        width: 1920,
        fps: 60,
        container: 'mp4',
        videoCodec: 'H.264',
        rawVideoCodec: 'avc1',
        audioCodec: 'AAC',
        videoItag: 137,
        audioItag: 140,
        videoSizeBytes: 50000000,
        audioSizeBytes: 3000000,
        compatibilityNote: 'Universal',
      );
      const v1080Webm = VideoStreamOption(
        id: '303+251',
        quality: VideoQuality.p1080,
        height: 1080,
        width: 1920,
        fps: 60,
        container: 'webm',
        videoCodec: 'VP9',
        rawVideoCodec: 'vp9',
        audioCodec: 'Opus',
        videoItag: 303,
        audioItag: 251,
        videoSizeBytes: 24000000,
        audioSizeBytes: 2800000,
        compatibilityNote: 'Alta eficiencia',
      );
      const aM4aHigh = AudioStreamOption(
        id: 'm4a_140',
        format: AudioFileFormat.m4a,
        extension: 'm4a',
        codecLabel: 'AAC-LC',
        bitrateKbps: 128,
        qualityTier: 'Alta',
        sizeBytes: 3200000,
        itag: 140,
        note: 'Nativo iOS/Android',
      );
      const aM4aLow = AudioStreamOption(
        id: 'm4a_139',
        format: AudioFileFormat.m4a,
        extension: 'm4a',
        codecLabel: 'HE-AAC',
        bitrateKbps: 49,
        qualityTier: 'Ligera',
        sizeBytes: 1200000,
        itag: 139,
        note: 'Ahorro de datos',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return AuraFormatSelector(
                    selectedMediaType: mediaType,
                    selectedQuality: quality,
                    availableQualities: const [
                      VideoQuality.best,
                      VideoQuality.p1080,
                      VideoQuality.p720,
                    ],
                    videoOptions: const [v1080Mp4, v1080Webm],
                    selectedVideoOption: selectedVideo ?? v1080Mp4,
                    onVideoOptionChanged: (o) =>
                        setState(() => selectedVideo = o),
                    audioOptions: const [aM4aHigh, aM4aLow],
                    selectedAudioOption: selectedAudio ?? aM4aHigh,
                    onAudioOptionChanged: (o) =>
                        setState(() => selectedAudio = o),
                    selectedAudioFormat: audioFormat,
                    onAudioFormatChanged: (f) =>
                        setState(() => audioFormat = f),
                    onMediaTypeChanged: (t) => setState(() => mediaType = t),
                    onQualityChanged: (q) => setState(() => quality = q),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alta · 128 kbps'), findsOneWidget);
      expect(find.text('Ligera · 49 kbps'), findsOneWidget);
      await tester.tap(find.text('Ligera · 49 kbps'));
      await tester.pumpAndSettle();
      expect(selectedAudio?.itag, 139);

      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      expect(find.text('MP4 · H.264 + AAC'), findsOneWidget);
      expect(find.text('WEBM · VP9 + Opus'), findsOneWidget);

      await tester.tap(find.text('WEBM · VP9 + Opus'));
      await tester.pumpAndSettle();
      expect(selectedVideo?.videoItag, 303);
    });
  });
}
