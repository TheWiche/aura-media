import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medias_download/core/services/settings_service.dart';
import 'package:medias_download/core/theme/aura_colors.dart';
import 'package:medias_download/core/theme/aura_theme.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/shared/widgets/aura_format_selector.dart';
import 'package:medias_download/shared/widgets/aura_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aura Musicolet-style Customization & Centering', () {
    testWidgets(
        'AuraTheme.buildDark AMOLED & accent exposes matching AuraThemeTokens',
        (tester) async {
      final amoledBlue = AuraTheme.buildDark(
        amoled: true,
        accent: AuraAccentPreset.blue,
        reduceAnimations: true,
      );

      expect(amoledBlue.brightness, Brightness.dark);
      expect(amoledBlue.scaffoldBackgroundColor, AuraColors.amoledBackground);
      expect(amoledBlue.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(amoledBlue.colorScheme.primary, AuraAccentPreset.blue.darkColor);

      AuraThemeTokens? capturedTokens;
      await tester.pumpWidget(
        MaterialApp(
          theme: amoledBlue,
          home: Builder(
            builder: (context) {
              capturedTokens = AuraThemeTokens.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(capturedTokens, isNotNull);
      expect(capturedTokens!.isAmoled, isTrue);
      expect(capturedTokens!.isDark, isTrue);
      expect(capturedTokens!.reduceAnimations, isTrue);
      expect(capturedTokens!.accentPreset, AuraAccentPreset.blue);
      expect(capturedTokens!.primary, const Color(0xFF60A5FA));
      expect(capturedTokens!.background, const Color(0xFF000000));
      expect(capturedTokens!.card, AuraColors.amoledCard);
    });

    testWidgets('AuraLogo tints ribbon with theme accent and adapts play mark',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.buildDark(
            amoled: true,
            accent: AuraAccentPreset.blue,
          ),
          home: const Scaffold(
            body: Center(child: AuraLogo(size: 48)),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, 2);

      final ribbonImage = images[0];
      final playImage = images[1];

      expect(
        (ribbonImage.image as AssetImage).assetName,
        'assets/icon/aura_logo_ribbon.png',
      );
      expect(ribbonImage.color, AuraAccentPreset.blue.darkColor);
      expect(ribbonImage.colorBlendMode, BlendMode.modulate);

      expect(
        (playImage.image as AssetImage).assetName,
        'assets/icon/aura_logo_play.png',
      );
      expect(playImage.color, AuraColors.white);

      // Verify light mode switches play mark to dark charcoal
      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.buildLight(accent: AuraAccentPreset.violet),
          home: const Scaffold(
            body: Center(child: AuraLogo(size: 48)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightImages = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(lightImages[0].color, AuraAccentPreset.violet.lightColor);
      expect(lightImages[1].color, const Color(0xFF1E1E24));
    });

    testWidgets(
        'AuraFormatSelector centers Solo Audio and Video icons and labels horizontally',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 380,
              child: AuraFormatSelector(
                selectedMediaType: MediaType.audio,
                selectedQuality: VideoQuality.best,
                onMediaTypeChanged: (_) {},
                onQualityChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final audioTile = find.ancestor(
        of: find.text('Solo Audio'),
        matching: find.byType(InkWell),
      );
      final videoTile = find.ancestor(
        of: find.text('Video'),
        matching: find.byType(InkWell),
      );

      expect(audioTile, findsOneWidget);
      expect(videoTile, findsOneWidget);

      final audioTileCenterX = tester.getCenter(audioTile).dx;
      final audioLabelCenterX = tester.getCenter(find.text('Solo Audio')).dx;
      final audioIconCenterX =
          tester.getCenter(find.byIcon(Icons.music_note_rounded)).dx;

      expect(audioLabelCenterX, closeTo(audioTileCenterX, 0.5));
      expect(audioIconCenterX, closeTo(audioTileCenterX, 0.5));

      final videoTileCenterX = tester.getCenter(videoTile).dx;
      final videoLabelCenterX = tester.getCenter(find.text('Video')).dx;
      final videoIconCenterX =
          tester.getCenter(find.byIcon(Icons.videocam_rounded)).dx;

      expect(videoLabelCenterX, closeTo(videoTileCenterX, 0.5));
      expect(videoIconCenterX, closeTo(videoTileCenterX, 0.5));
    });

    test(
        'SettingsService persists AMOLED, accent preset, animations and preferred players',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.initialize();

      int notifications = 0;
      void listener() => notifications++;
      SettingsService.instance.changesNotifier.addListener(listener);

      await SettingsService.instance.setAmoledDark(true);
      await SettingsService.instance.setAccentPreset(AuraAccentPreset.cyan);
      await SettingsService.instance.setReduceAnimations(true);
      await SettingsService.instance.setAudioPlayer(
        packageName: 'in.krosbits.musicolet',
        appName: 'Musicolet',
      );
      await SettingsService.instance.setVideoPlayer(
        packageName: 'org.videolan.vlc',
        appName: 'VLC',
      );

      expect(SettingsService.instance.getAmoledDark(), isTrue);
      expect(
          SettingsService.instance.getAccentPreset(), AuraAccentPreset.cyan);
      expect(SettingsService.instance.getReduceAnimations(), isTrue);
      expect(
        SettingsService.instance.getAudioPlayerPackage(),
        'in.krosbits.musicolet',
      );
      expect(SettingsService.instance.getAudioPlayerName(), 'Musicolet');
      expect(
        SettingsService.instance.getVideoPlayerPackage(),
        'org.videolan.vlc',
      );
      expect(SettingsService.instance.getVideoPlayerName(), 'VLC');
      expect(notifications, 5);

      // Clearing player restores system default (null)
      await SettingsService.instance.setAudioPlayer();
      await SettingsService.instance.setVideoPlayer(packageName: '');

      expect(SettingsService.instance.getAudioPlayerPackage(), isNull);
      expect(SettingsService.instance.getAudioPlayerName(), isNull);
      expect(SettingsService.instance.getVideoPlayerPackage(), isNull);
      expect(SettingsService.instance.getVideoPlayerName(), isNull);
      expect(notifications, 7);

      SettingsService.instance.changesNotifier.removeListener(listener);
    });
  });
}
