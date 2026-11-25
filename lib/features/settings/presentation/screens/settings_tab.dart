import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/background_service.dart';
import '../../../../core/services/native_platform_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../shared/widgets/aura_card.dart';
import '../../../downloader/data/models/download_task.dart';
import '../../../downloader/presentation/bloc/download_bloc.dart';
import '../../../downloader/presentation/bloc/download_event.dart';

/// Settings screen styled with Aura Core Design System 1.0.
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
  late MediaType _defaultMediaType;
  late ShareBehavior _shareBehavior;
  late bool _autoCloseShareModal;
  late AudioFileFormat _audioFormat;
  late DuplicateFilePolicy _duplicatePolicy;
  late bool _includeAuthor;
  late bool _scanMediaLibrary;
  late bool _wifiOnly;
  late int _maxConcurrency;
  late bool _saveHistory;

  String _audioDownloadPath = '';
  String _videoDownloadPath = '';
  bool _hasCustomAudioPath = false;
  bool _hasCustomVideoPath = false;

  bool _storagePermissionGranted = false;
  bool _batteryOptimizationIgnored = false;
  String _appVersion = '1.3.0+10';

  @override
  void initState() {
    super.initState();
    _loadSettingsValues();
    SettingsService.instance.changesNotifier.addListener(_onSettingsChanged);
    _loadPathsAndSystemStatus();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _loadSettingsValues();
    });
  }

  @override
  void dispose() {
    SettingsService.instance.changesNotifier.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _loadSettingsValues() {
    final s = SettingsService.instance;
    _defaultQuality = s.getDefaultQuality();
    _defaultMediaType = s.getDefaultMediaType();
    _shareBehavior = s.getShareBehavior();
    _autoCloseShareModal = s.getAutoCloseShareModal();
    _audioFormat = s.getAudioFormat();
    _duplicatePolicy = s.getDuplicatePolicy();
    _includeAuthor = s.getIncludeAuthorInFilename();
    _scanMediaLibrary = s.getScanMediaLibrary();
    _wifiOnly = s.getWifiOnly();
    _maxConcurrency = s.getMaxConcurrentDownloads();
    _saveHistory = s.getSaveDownloadHistory();
  }

  Future<void> _loadPathsAndSystemStatus() async {
    try {
      final audioDir =
          await StorageService.instance.getDownloadDirectory(MediaType.audio);
      final videoDir =
          await StorageService.instance.getDownloadDirectory(MediaType.video);
      final hasStorage =
          await PermissionService.instance.hasStoragePermission();
      final batteryOk =
          await PermissionService.instance.isBatteryOptimizationIgnored();
      final version = await NativePlatformService.instance.getAppVersion();

      if (!mounted) return;
      setState(() {
        _audioDownloadPath = audioDir.path;
        _videoDownloadPath = videoDir.path;
        _hasCustomAudioPath =
            SettingsService.instance.getAudioDownloadPath() != null;
        _hasCustomVideoPath =
            SettingsService.instance.getVideoDownloadPath() != null;
        _storagePermissionGranted = hasStorage;
        _batteryOptimizationIgnored = batteryOk;
        _appVersion = version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_audioDownloadPath.isEmpty) _audioDownloadPath = 'No disponible';
        if (_videoDownloadPath.isEmpty) _videoDownloadPath = 'No disponible';
      });
    }
  }

  Future<void> _onThemeModeChanged(ThemeMode? mode) async {
    if (mode == null) return;
    await SettingsService.instance.setThemeMode(mode);
    widget.onThemeModeChanged(mode);
  }

  Future<void> _pickFolderFor(MediaType mediaType) async {
    if (Platform.isAndroid &&
        !await PermissionService.instance.hasManageExternalStorage()) {
      if (!mounted) return;
      final shouldRequest = await _showStoragePermissionPrompt();
      if (shouldRequest == true) {
        await PermissionService.instance.requestManageExternalStorage();
      }
    }

    final picked = await NativePlatformService.instance.pickDirectory();
    if (picked == null || picked.isEmpty) return;

    final writable =
        await StorageService.instance.isDirectoryWritable(picked);
    if (!writable) {
      if (!mounted) return;
      _showSnack(
        'No se pudo escribir en esa carpeta. Concede "Acceso a todos los archivos" o elige otra carpeta.',
        isError: true,
      );
      return;
    }

    if (mediaType == MediaType.audio) {
      await SettingsService.instance.setAudioDownloadPath(picked);
    } else {
      await SettingsService.instance.setVideoDownloadPath(picked);
    }

    await BackgroundService.instance.notifySettingsUpdated();
    await _loadPathsAndSystemStatus();

    if (mounted) {
      _showSnack(
        mediaType == MediaType.audio
            ? 'Carpeta de audio actualizada'
            : 'Carpeta de video actualizada',
      );
    }
  }

  Future<void> _resetFolderFor(MediaType mediaType) async {
    if (mediaType == MediaType.audio) {
      await SettingsService.instance.setAudioDownloadPath(null);
    } else {
      await SettingsService.instance.setVideoDownloadPath(null);
    }
    await BackgroundService.instance.notifySettingsUpdated();
    await _loadPathsAndSystemStatus();
    if (mounted) {
      _showSnack('Carpeta predeterminada restaurada');
    }
  }

  Future<bool?> _showStoragePermissionPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Permiso de almacenamiento',
          style: AuraTypography.headingSmall
              .copyWith(color: AuraColors.textPrimary(isDark)),
        ),
        content: Text(
          'Para guardar archivos MP3 y MP4 en carpetas personalizadas (como Music o Movies) en Android 11+, conviene activar "Acceso a todos los archivos".',
          style: AuraTypography.bodyMedium.copyWith(
            color: AuraColors.textSecondary(isDark),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conceder acceso'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AuraTypography.bodyMedium.copyWith(
            color: isError
                ? AuraColors.error(isDark)
                : AuraColors.textPrimary(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final primary = AuraColors.primary(isDark);
    final audioColor = AuraColors.audio(isDark);
    final videoColor = AuraColors.video(isDark);
    final warningColor = AuraColors.warning(isDark);
    final divider = AuraColors.divider(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraDimensions.space5,
        vertical: AuraDimensions.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Text(
            'Ajustes',
            style: AuraTypography.headingLarge.copyWith(color: textPrimary),
          ),
          const SizedBox(height: AuraDimensions.space1),
          Text(
            'Personaliza ${AppConstants.appName}, carpetas y descargas rápidas.',
            style: AuraTypography.bodyMedium.copyWith(color: textSecondary),
          ),
          const SizedBox(height: AuraDimensions.space6),

          // ── Apariencia ──────────────────────────────────────────────────────
          const _SectionHeader(label: 'Apariencia'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: _DropdownRow<ThemeMode>(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              iconColor: primary,
              title: 'Tema de la app',
              subtitle: 'Claro, oscuro o automático del sistema',
              value: widget.currentThemeMode,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
              ],
              onChanged: _onThemeModeChanged,
            ),
          ),

          const SizedBox(height: AuraDimensions.space6),

          // ── Al compartir enlace ────────────────────────────────────────────
          const _SectionHeader(label: 'Al compartir enlace'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: Column(
              children: [
                _DropdownRow<ShareBehavior>(
                  icon: Icons.bolt_rounded,
                  iconColor: primary,
                  title: 'Acción al compartir',
                  subtitle: 'Cómo responde Aura desde YouTube u otra app',
                  value: _shareBehavior,
                  items: const [
                    DropdownMenuItem(
                        value: ShareBehavior.modal,
                        child: Text('Modal rápido')),
                    DropdownMenuItem(
                        value: ShareBehavior.autoDownload,
                        child: Text('Auto-descarga')),
                    DropdownMenuItem(
                        value: ShareBehavior.openApp, child: Text('Abrir app')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    await SettingsService.instance.setShareBehavior(val);
                    setState(() => _shareBehavior = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                _DropdownRow<MediaType>(
                  icon: Icons.audiotrack_rounded,
                  iconColor: audioColor,
                  title: 'Formato predeterminado',
                  subtitle: 'Preseleccionado al abrir o compartir',
                  value: _defaultMediaType,
                  items: const [
                    DropdownMenuItem(
                        value: MediaType.audio, child: Text('Solo Audio')),
                    DropdownMenuItem(
                        value: MediaType.video, child: Text('Video')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    await SettingsService.instance.setDefaultMediaType(val);
                    setState(() => _defaultMediaType = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.exit_to_app_rounded,
                    color: audioColor,
                  ),
                  title: Text(
                    'Cerrar modal al descargar',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: textPrimary),
                  ),
                  subtitle: Text(
                    'Volver automáticamente a YouTube al iniciar',
                    style: AuraTypography.bodySmall
                        .copyWith(color: textSecondary),
                  ),
                  value: _autoCloseShareModal,
                  onChanged: (val) async {
                    await SettingsService.instance.setAutoCloseShareModal(val);
                    setState(() => _autoCloseShareModal = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraDimensions.space6),

          // ── Carpetas de descarga (Audio verde / Video violeta) ─────────────
          const _SectionHeader(label: 'Carpetas de descarga'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: Column(
              children: [
                _FolderTile(
                  icon: Icons.music_note_rounded,
                  iconColor: audioColor,
                  title: 'Carpeta de Audio (${_audioFormat.name.toUpperCase()})',
                  path: _audioDownloadPath,
                  hasCustomPath: _hasCustomAudioPath,
                  onPick: () => _pickFolderFor(MediaType.audio),
                  onReset: _hasCustomAudioPath
                      ? () => _resetFolderFor(MediaType.audio)
                      : null,
                  onOpen: () => NativePlatformService.instance
                      .openFolder(_audioDownloadPath),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                _FolderTile(
                  icon: Icons.videocam_rounded,
                  iconColor: videoColor,
                  title: 'Carpeta de Video (MP4)',
                  path: _videoDownloadPath,
                  hasCustomPath: _hasCustomVideoPath,
                  onPick: () => _pickFolderFor(MediaType.video),
                  onReset: _hasCustomVideoPath
                      ? () => _resetFolderFor(MediaType.video)
                      : null,
                  onOpen: () => NativePlatformService.instance
                      .openFolder(_videoDownloadPath),
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraDimensions.space6),

          // ── Descargas y archivos ───────────────────────────────────────────
          const _SectionHeader(label: 'Descargas y archivos'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: Column(
              children: [
                _DropdownRow<VideoQuality>(
                  icon: Icons.high_quality_rounded,
                  iconColor: videoColor,
                  title: 'Calidad de video',
                  subtitle: 'Resolución predeterminada para MP4',
                  value: _defaultQuality,
                  items: const [
                    DropdownMenuItem(
                        value: VideoQuality.best, child: Text('Mejor')),
                    DropdownMenuItem(
                        value: VideoQuality.p1080, child: Text('1080p')),
                    DropdownMenuItem(
                        value: VideoQuality.p720, child: Text('720p')),
                    DropdownMenuItem(
                        value: VideoQuality.p480, child: Text('480p')),
                    DropdownMenuItem(
                        value: VideoQuality.p360, child: Text('360p')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    await SettingsService.instance.setDefaultQuality(val);
                    setState(() => _defaultQuality = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                _DropdownRow<AudioFileFormat>(
                  icon: Icons.library_music_rounded,
                  iconColor: audioColor,
                  title: 'Extensión de audio',
                  subtitle: 'MP3 compatible o M4A AAC nativo',
                  value: _audioFormat,
                  items: const [
                    DropdownMenuItem(
                        value: AudioFileFormat.mp3, child: Text('MP3')),
                    DropdownMenuItem(
                        value: AudioFileFormat.m4a, child: Text('M4A')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    await SettingsService.instance.setAudioFormat(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                    setState(() => _audioFormat = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                _DropdownRow<int>(
                  icon: Icons.sync_alt_rounded,
                  iconColor: primary,
                  title: 'Descargas simultáneas',
                  subtitle: 'Límite máximo activo al mismo tiempo',
                  value: _maxConcurrency,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 a la vez')),
                    DropdownMenuItem(value: 2, child: Text('2 a la vez')),
                    DropdownMenuItem(value: 3, child: Text('3 a la vez')),
                    DropdownMenuItem(value: 4, child: Text('4 a la vez')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    DownloadBloc? bloc;
                    try {
                      bloc = context.read<DownloadBloc>();
                    } catch (_) {}
                    await SettingsService.instance
                        .setMaxConcurrentDownloads(val);
                    bloc?.add(UpdateConcurrencyLimitEvent(val));
                    if (!mounted) return;
                    setState(() => _maxConcurrency = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                _DropdownRow<DuplicateFilePolicy>(
                  icon: Icons.file_copy_outlined,
                  iconColor: warningColor,
                  title: 'Si el archivo existe',
                  subtitle: 'Acción cuando el nombre ya está en la carpeta',
                  value: _duplicatePolicy,
                  items: const [
                    DropdownMenuItem(
                        value: DuplicateFilePolicy.rename,
                        child: Text('Renombrar (1)')),
                    DropdownMenuItem(
                        value: DuplicateFilePolicy.overwrite,
                        child: Text('Sobrescribir')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    await SettingsService.instance.setDuplicatePolicy(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                    setState(() => _duplicatePolicy = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.person_outline_rounded,
                    color: primary,
                  ),
                  title: Text(
                    'Incluir autor en nombre',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: textPrimary),
                  ),
                  subtitle: Text(
                    'Guardar como "Canal - Título"',
                    style: AuraTypography.bodySmall
                        .copyWith(color: textSecondary),
                  ),
                  value: _includeAuthor,
                  onChanged: (val) async {
                    await SettingsService.instance
                        .setIncludeAuthorInFilename(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                    setState(() => _includeAuthor = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.perm_media_outlined,
                    color: audioColor,
                  ),
                  title: Text(
                    'Indexar en Galería y Música',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: textPrimary),
                  ),
                  subtitle: Text(
                    'Mostrar al instante en reproductores del sistema',
                    style: AuraTypography.bodySmall
                        .copyWith(color: textSecondary),
                  ),
                  value: _scanMediaLibrary,
                  onChanged: (val) async {
                    await SettingsService.instance.setScanMediaLibrary(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                    setState(() => _scanMediaLibrary = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraDimensions.space6),

          // ── Red y sistema ──────────────────────────────────────────────────
          const _SectionHeader(label: 'Red y sistema'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.wifi_rounded,
                    color: videoColor,
                  ),
                  title: Text(
                    'Solo descargar con Wi-Fi',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: textPrimary),
                  ),
                  subtitle: Text(
                    'Pausa descargas si estás usando datos móviles',
                    style: AuraTypography.bodySmall
                        .copyWith(color: textSecondary),
                  ),
                  value: _wifiOnly,
                  onChanged: (val) async {
                    await SettingsService.instance.setWifiOnly(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                    setState(() => _wifiOnly = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.history_rounded,
                    color: primary,
                  ),
                  title: Text(
                    'Conservar historial',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: textPrimary),
                  ),
                  subtitle: Text(
                    'Mantener descargas completadas al reiniciar',
                    style: AuraTypography.bodySmall
                        .copyWith(color: textSecondary),
                  ),
                  value: _saveHistory,
                  onChanged: (val) async {
                    await SettingsService.instance.setSaveDownloadHistory(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                    setState(() => _saveHistory = val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  leading: _IconBadge(
                    icon: _storagePermissionGranted
                        ? Icons.verified_user_rounded
                        : Icons.folder_off_rounded,
                    color:
                        _storagePermissionGranted ? audioColor : warningColor,
                  ),
                  title: Text(
                    'Permiso de almacenamiento',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: textPrimary),
                  ),
                  subtitle: Text(
                    _storagePermissionGranted
                        ? 'Concedido · Lectura y escritura lista'
                        : 'Toca para conceder acceso a carpetas',
                    style: AuraTypography.bodySmall.copyWith(
                      color:
                          _storagePermissionGranted ? audioColor : warningColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: AuraDimensions.smallIconSize,
                    color: textSecondary,
                  ),
                  onTap: () async {
                    await PermissionService.instance
                        .requestManageExternalStorage();
                    await PermissionService.instance.requestStoragePermission();
                    await _loadPathsAndSystemStatus();
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: divider),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  leading: _IconBadge(
                    icon: Icons.battery_saver_rounded,
                    color:
                        _batteryOptimizationIgnored ? audioColor : warningColor,
                  ),
                  title: Text(
                    'Segundo plano (Batería)',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: textPrimary),
                  ),
                  subtitle: Text(
                    _batteryOptimizationIgnored
                        ? 'Sin restricciones · Descargas largas protegidas'
                        : 'Toca para evitar cierres en segundo plano',
                    style: AuraTypography.bodySmall.copyWith(
                      color: _batteryOptimizationIgnored
                          ? audioColor
                          : warningColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: AuraDimensions.smallIconSize,
                    color: textSecondary,
                  ),
                  onTap: () async {
                    await PermissionService.instance
                        .requestIgnoreBatteryOptimization();
                    await _loadPathsAndSystemStatus();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraDimensions.space6),

          // ── About ───────────────────────────────────────────────────────────
          const _SectionHeader(label: 'Acerca de'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AuraDimensions.space4, vertical: 6),
              leading: Image.asset(
                'assets/icon/aura_logo.png',
                width: 32,
                height: 32,
              ),
              title: Text(
                AppConstants.appFullName,
                style: AuraTypography.label
                    .copyWith(fontSize: 15, color: textPrimary),
              ),
              subtitle: Text(
                'v$_appVersion · ${AppConstants.appTagline}',
                style: AuraTypography.metricSmall.copyWith(
                  color: textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AuraDimensions.space8),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label.toUpperCase(),
      style: AuraTypography.bodySmall.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AuraColors.primary(isDark),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AuraDimensions.radiusSmall,
      ),
      child: Icon(icon, color: color, size: AuraDimensions.smallIconSize),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final primary = AuraColors.primary(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AuraDimensions.space4, vertical: 10),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: AuraDimensions.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraTypography.label
                      .copyWith(fontSize: 15, color: textPrimary),
                ),
                Text(
                  subtitle,
                  style: AuraTypography.bodySmall.copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraDimensions.space2),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: AuraColors.surface(isDark),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: primary,
                size: AuraDimensions.smallIconSize,
              ),
              style: AuraTypography.label.copyWith(
                fontSize: 13,
                color: primary,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String path;
  final bool hasCustomPath;
  final VoidCallback onPick;
  final VoidCallback? onReset;
  final VoidCallback onOpen;

  const _FolderTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.path,
    required this.hasCustomPath,
    required this.onPick,
    required this.onReset,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final primary = AuraColors.primary(isDark);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraDimensions.space4, vertical: 6),
      leading: _IconBadge(icon: icon, color: iconColor),
      title: Text(
        title,
        style: AuraTypography.label.copyWith(fontSize: 15, color: textPrimary),
      ),
      subtitle: Text(
        path.isEmpty ? 'Cargando...' : path,
        style: AuraTypography.metricSmall.copyWith(
          fontSize: 11,
          color: textSecondary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReset != null)
            IconButton(
              icon: Icon(Icons.restore_rounded, size: 19, color: textSecondary),
              tooltip: 'Restaurar predeterminada',
              onPressed: onReset,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: Icon(Icons.launch_rounded, size: 18, color: textSecondary),
            tooltip: 'Abrir carpeta',
            onPressed: onOpen,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 19, color: primary),
            tooltip: 'Cambiar carpeta',
            onPressed: onPick,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      onTap: onPick,
    );
  }
}
