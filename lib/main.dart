import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
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

  // Request permissions in advance
  await PermissionService.instance.requestNotificationPermission();

  runApp(const MediasDownloadApp());
}

class MediasDownloadApp extends StatelessWidget {
  const MediasDownloadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloadBloc(),
      child: MaterialApp(
        title: "Media's Download",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
