import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_state.dart';
import 'completed_tab.dart';
import 'home_tab.dart';
import 'queue_tab.dart';
import '../../../settings/presentation/screens/settings_tab.dart';

class MainScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const MainScreen({
    super.key,
    required this.onThemeModeChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final activeCount = state.activeTasks.length;
        final completedCount = state.completedTasks.length;

        final screens = [
          HomeTab(onNavigateToQueue: () => _onTabSelected(1)),
          QueueTab(onNavigateToHome: () => _onTabSelected(0)),
          const CompletedTab(),
          SettingsTab(
            currentThemeMode: currentThemeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cloud_download_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              if (state.downloadingCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${state.downloadingCount} activas',
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.add_link_outlined),
                selectedIcon: Icon(Icons.add_link),
                label: 'Descargar',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
                  child: const Icon(Icons.downloading_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
                  child: const Icon(Icons.downloading),
                ),
                label: 'Cola',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: completedCount > 0,
                  label: Text('$completedCount'),
                  child: const Icon(Icons.folder_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: completedCount > 0,
                  label: Text('$completedCount'),
                  child: const Icon(Icons.folder),
                ),
                label: 'Completados',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        );
      },
    );
  }
}
