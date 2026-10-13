import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'features/downloader/presentation/bloc/download_bloc.dart';
import 'features/downloader/presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService.instance.initialize(
    onNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        // Tapping completed notification opens the media file
        OpenFilex.open(payload);
      }
    },
  );

  // Initialize foreground service options
  BackgroundService.instance.initialize();

  // Initialize persistent settings (theme mode, quality prefs)
  await SettingsService.instance.initialize();

  // Request permissions in advance
  await PermissionService.instance.requestNotificationPermission();

  runApp(AuraApp(initialThemeMode: SettingsService.instance.getThemeMode()));
}

class AuraApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const AuraApp({super.key, required this.initialThemeMode});

  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: MainScreen(onThemeModeChanged: _onThemeModeChanged),
      ),
    );
  }
}
