import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/native_platform_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/share_intent_service.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../shared/navigation/aura_bottom_navigation.dart';
import '../../../settings/presentation/screens/settings_tab.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import 'completed_tab.dart';
import 'home_tab.dart';
import 'queue_tab.dart';

class MainScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const MainScreen({
    super.key,
    required this.onThemeModeChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  late ThemeMode _selectedThemeMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedThemeMode = SettingsService.instance.getThemeMode();

    ShareIntentService.instance.initialize(
      onUrlReceived: _openIncomingUrlInHome,
    );

    NativePlatformService.instance.setOpenMainUrlHandler(_openIncomingUrlInHome);
    NativePlatformService.instance.getMainOpenUrl().then((url) {
      if (url != null && url.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openIncomingUrlInHome(url);
        });
      }
    });
  }

  void _openIncomingUrlInHome(String url) {
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
    });
    _homeTabKey.currentState?.handleIncomingUrl(url);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      SettingsService.instance.reload();
      context.read<DownloadBloc>().add(const SyncTasksEvent());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShareIntentService.instance.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleThemeModeChanged(ThemeMode mode) {
    setState(() => _selectedThemeMode = mode);
    widget.onThemeModeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AuraColors.primary(isDark);

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final activeCount = state.activeTasks.length;
        final completedCount = state.completedTasks.length;

        final screens = [
          HomeTab(
            key: _homeTabKey,
            onNavigateToQueue: () => _onTabSelected(1),
          ),
          QueueTab(onNavigateToHome: () => _onTabSelected(0)),
          const CompletedTab(),
          SettingsTab(
            currentThemeMode: _selectedThemeMode,
            onThemeModeChanged: _handleThemeModeChanged,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: AuraDimensions.space5,
            title: Row(
              children: [
                Image.asset(
                  'assets/icon/aura_logo.png',
                  width: 28,
                  height: 28,
                ),
                const SizedBox(width: AuraDimensions.space2),
                Text(
                  AppConstants.appName,
                  style: AuraTypography.headingMedium.copyWith(
                    color: AuraColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
            actions: [
              if (state.downloadingCount > 0)
                GestureDetector(
                  onTap: () => _onTabSelected(1),
                  child: Container(
                    margin: const EdgeInsets.only(right: AuraDimensions.space2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space3,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.14),
                      borderRadius: AuraDimensions.radiusFull,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${state.downloadingCount} activas',
                          style: AuraTypography.metricSmall.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Ajustes',
                onPressed: () => _onTabSelected(3),
                icon: Icon(
                  Icons.settings_outlined,
                  color: _currentIndex == 3
                      ? primary
                      : AuraColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(width: AuraDimensions.space2),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: AuraBottomNavigation(
            currentIndex: _currentIndex,
            activeCount: activeCount,
            completedCount: completedCount,
            onDestinationSelected: _onTabSelected,
          ),
        );
      },
    );
  }
}
