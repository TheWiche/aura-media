import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../downloader/data/models/download_task.dart';

/// Settings screen — theme toggle, download path display, default quality.
class SettingsTab extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsTab({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late VideoQuality _defaultQuality;
  String _downloadPath = '';

  @override
  void initState() {
    super.initState();
    _defaultQuality = SettingsService.instance.getDefaultQuality();
    _loadDownloadPath();
  }

  Future<void> _loadDownloadPath() async {
    try {
      final dir = await StorageService.instance.getDownloadDirectory();
      if (mounted) setState(() => _downloadPath = dir.path);
    } catch (_) {
      if (mounted) setState(() => _downloadPath = 'No disponible');
    }
  }

  Future<void> _onThemeToggle(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    await SettingsService.instance.setThemeMode(mode);
    widget.onThemeModeChanged(mode);
  }

  Future<void> _onQualityChanged(VideoQuality? quality) async {
    if (quality == null) return;
    await SettingsService.instance.setDefaultQuality(quality);
    setState(() => _defaultQuality = quality);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.currentThemeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Text(
            'Ajustes',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personaliza ${AppConstants.appName} a tu gusto.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 28),

          // ── Apariencia ──────────────────────────────────────────────────────
          _SectionHeader(label: 'Apariencia'),
          const SizedBox(height: 12),
          _SettingsCard(
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              title: Text(
                'Modo oscuro',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                isDark ? 'Tema oscuro activado' : 'Tema claro activado',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              value: isDark,
              activeTrackColor: AppColors.primary,
              onChanged: _onThemeToggle,
            ),
          ),

          const SizedBox(height: 20),

          // ── Descargas ───────────────────────────────────────────────────────
          _SectionHeader(label: 'Descargas'),
          const SizedBox(height: 12),
          _SettingsCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
              ),
              title: Text(
                'Carpeta de descargas',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                _downloadPath.isEmpty ? 'Cargando...' : _downloadPath,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                Icons.lock_outline,
                size: 16,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.high_quality_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calidad predeterminada',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Resolución al añadir a la cola',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<VideoQuality>(
                      value: _defaultQuality,
                      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      items: const [
                        DropdownMenuItem(value: VideoQuality.best, child: Text('Mejor')),
                        DropdownMenuItem(value: VideoQuality.p1080, child: Text('1080p')),
                        DropdownMenuItem(value: VideoQuality.p720, child: Text('720p')),
                        DropdownMenuItem(value: VideoQuality.p480, child: Text('480p')),
                        DropdownMenuItem(value: VideoQuality.p360, child: Text('360p')),
                      ],
                      onChanged: _onQualityChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── About ───────────────────────────────────────────────────────────
          _SectionHeader(label: 'Acerca de'),
          const SizedBox(height: 12),
          _SettingsCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_download_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              title: Text(
                AppConstants.appFullName,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'v1.1.0 · ${AppConstants.appTagline}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.primary,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}
