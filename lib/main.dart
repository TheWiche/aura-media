import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/services/background_service.dart';
import 'core/services/media_opener_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/settings_service.dart';
import 'core/theme/aura_colors.dart';
import 'core/theme/aura_theme.dart';
import 'features/downloader/presentation/bloc/download_bloc.dart';
import 'features/downloader/presentation/screens/main_screen.dart';
import 'features/share_modal/presentation/screens/share_modal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService.instance.initialize(
    onNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        MediaOpenerService.openFile(payload);
      }
    },
  );

  final launchPayload =
      await NotificationService.instance.getLaunchNotificationPayload();
  if (launchPayload != null && launchPayload.isNotEmpty) {
    MediaOpenerService.openFile(launchPayload);
  }

  // Initialize foreground service options
  BackgroundService.instance.initialize();

  // Initialize persistent settings
  await SettingsService.instance.initialize();
  await SettingsService.instance.reload();

  // Request notification permission in advance
  await PermissionService.instance.requestNotificationPermission();

  runApp(AuraApp(initialThemeMode: SettingsService.instance.getThemeMode()));
}

/// Dedicated entrypoint used by Android's translucent `ShareModalActivity`.
@pragma('vm:entry-point')
void shareModalMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.initialize(
    onNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        MediaOpenerService.openFile(payload);
      }
    },
  );

  BackgroundService.instance.initialize();
  await SettingsService.instance.initialize();
  await SettingsService.instance.reload();

  runApp(
    ShareModalApp(initialThemeMode: SettingsService.instance.getThemeMode()),
  );
}

class AuraApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const AuraApp({super.key, required this.initialThemeMode});

  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp> {
  late ThemeMode _themeMode;
  late bool _amoledDark;
  late AuraAccentPreset _accentPreset;
  late bool _reduceAnimations;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _readAppearanceFromSettings();
    SettingsService.instance.changesNotifier.addListener(_onSettingsChanged);
  }

  void _readAppearanceFromSettings() {
    _amoledDark = SettingsService.instance.getAmoledDark();
    _accentPreset = SettingsService.instance.getAccentPreset();
    _reduceAnimations = SettingsService.instance.getReduceAnimations();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _themeMode = SettingsService.instance.getThemeMode();
      _readAppearanceFromSettings();
    });
  }

  @override
  void dispose() {
    SettingsService.instance.changesNotifier.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onThemeModeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloadBloc(),
      child: MaterialApp(
        title: 'Aura',
        debugShowCheckedModeBanner: false,
        theme: AuraTheme.buildLight(
          accent: _accentPreset,
          reduceAnimations: _reduceAnimations,
        ),
        darkTheme: AuraTheme.buildDark(
          amoled: _amoledDark,
          accent: _accentPreset,
          reduceAnimations: _reduceAnimations,
        ),
        themeMode: _themeMode,
        home: MainScreen(onThemeModeChanged: _onThemeModeChanged),
      ),
    );
  }
}
