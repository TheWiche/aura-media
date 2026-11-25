import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';
import '../../core/theme/aura_typography.dart';

class AuraBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final int activeCount;
  final int completedCount;
  final ValueChanged<int> onDestinationSelected;

  const AuraBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.activeCount,
    required this.completedCount,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AuraColors.primary(isDark);
    final badgeFg = isDark ? const Color(0xFF171D15) : AuraColors.white;

    return Container(
      decoration: BoxDecoration(
        color: AuraColors.card(isDark),
        border: Border(
          top: BorderSide(color: AuraColors.divider(isDark), width: 1),
        ),
      ),
      child: NavigationBar(
        height: AuraDimensions.navigationHeight,
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Descargar',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              backgroundColor: primary,
              textColor: badgeFg,
              label: Text(
                '$activeCount',
                style: AuraTypography.metricSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
              child: const Icon(Icons.downloading_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeCount > 0,
              backgroundColor: primary,
              textColor: badgeFg,
              label: Text(
                '$activeCount',
                style: AuraTypography.metricSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
              child: const Icon(Icons.downloading_rounded),
            ),
            label: 'Cola',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: completedCount > 0,
              backgroundColor: AuraColors.audio(isDark),
              textColor: badgeFg,
              label: Text(
                '$completedCount',
                style: AuraTypography.metricSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
              child: const Icon(Icons.check_circle_outline_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: completedCount > 0,
              backgroundColor: AuraColors.audio(isDark),
              textColor: badgeFg,
              label: Text(
                '$completedCount',
                style: AuraTypography.metricSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
              child: const Icon(Icons.check_circle_rounded),
            ),
            label: 'Completados',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
