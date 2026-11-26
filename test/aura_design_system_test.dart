import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medias_download/core/theme/aura_colors.dart';
import 'package:medias_download/core/theme/aura_dimensions.dart';
import 'package:medias_download/core/theme/aura_theme.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/shared/navigation/aura_bottom_navigation.dart';
import 'package:medias_download/shared/widgets/aura_button.dart';
import 'package:medias_download/shared/widgets/aura_download_card.dart';
import 'package:medias_download/shared/widgets/aura_format_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aura Core Design System', () {
    test('Color tokens match neutral Aura Core specification', () {
      expect(AuraColors.darkBackground, const Color(0xFF0E0E11));
      expect(AuraColors.darkSurface, const Color(0xFF16161B));
      expect(AuraColors.darkCard, const Color(0xFF1E1E24));
      expect(AuraColors.amoledBackground, const Color(0xFF000000));
      expect(AuraColors.amoledSurface, const Color(0xFF09090B));
      expect(AuraColors.amoledCard, const Color(0xFF121216));
      expect(AuraColors.darkPrimary, const Color(0xFFC1F36B));
      expect(AuraColors.darkAudio, const Color(0xFF4ADE80));
      expect(AuraColors.darkVideo, const Color(0xFF818CF8));

      expect(AuraColors.lightBackground, const Color(0xFFF5F6F8));
      expect(AuraColors.lightSurface, const Color(0xFFFFFFFF));
      expect(AuraColors.lightPrimary, const Color(0xFF527B13));
      expect(AuraColors.lightAudio, const Color(0xFF16A34A));
      expect(AuraColors.lightVideo, const Color(0xFF4F46E5));
    });

    test('Dark & Light Material 3 themes apply Aura Core colors', () {
      final dark = AuraTheme.dark;
      final light = AuraTheme.light;

      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AuraColors.darkBackground);
      expect(dark.colorScheme.primary, AuraColors.darkPrimary);
      expect(dark.colorScheme.secondary, AuraColors.darkSecondary);

      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, AuraColors.lightBackground);
      expect(light.colorScheme.primary, AuraColors.lightPrimary);
      expect(light.colorScheme.secondary, AuraColors.lightSecondary);
    });

    testWidgets('AuraButton renders 54dp height and invokes onPressed',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.dark,
          home: Scaffold(
            body: Center(
              child: AuraButton(
                label: 'Descargar',
                icon: Icons.download_rounded,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(AuraButton));
      expect(size.height, AuraDimensions.buttonHeight);
      expect(find.text('Descargar'), findsOneWidget);

      await tester.tap(find.text('Descargar'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('AuraFormatSelector distinguishes Audio and Video and switches',
        (tester) async {
      MediaType selectedType = MediaType.audio;
      VideoQuality selectedQuality = VideoQuality.best;

      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AuraFormatSelector(
                  selectedMediaType: selectedType,
                  selectedQuality: selectedQuality,
                  onMediaTypeChanged: (t) => setState(() => selectedType = t),
                  onQualityChanged: (q) => setState(() => selectedQuality = q),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Solo Audio'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('1080p'), findsNothing);

      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      expect(selectedType, MediaType.video);
      expect(find.text('1080p'), findsOneWidget);

      await tester.tap(find.text('1080p'));
      await tester.pumpAndSettle();
      expect(selectedQuality, VideoQuality.p1080);
    });

    testWidgets('AuraDownloadCard shows title, progress percentage, and speed',
        (tester) async {
      final task = DownloadTask(
        id: 'id-1',
        notificationId: 1,
        url: 'https://youtube.com/watch?v=12345678901',
        title: 'Alan Walker - Faded',
        mediaType: MediaType.audio,
        fileExtension: 'mp3',
        totalBytes: 1000,
        downloadedBytes: 720,
        speedBytesPerSec: 1024 * 1024 * 8.42,
        status: DownloadStatus.downloading,
        createdAt: DateTime(2026, 11, 25),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.dark,
          home: Scaffold(
            body: AuraDownloadCard(task: task),
          ),
        ),
      );

      expect(find.text('Alan Walker - Faded'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.textContaining('8.42 MB/s'), findsOneWidget);
      expect(find.text('MP3 · Audio'), findsOneWidget);
    });

    testWidgets('AuraBottomNavigation displays badges and triggers navigation',
        (tester) async {
      int index = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.dark,
          home: Scaffold(
            bottomNavigationBar: AuraBottomNavigation(
              currentIndex: index,
              activeCount: 2,
              completedCount: 4,
              onDestinationSelected: (i) => index = i,
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.text('Ajustes'));
      await tester.pump();
      expect(index, 3);
    });
  });
}
