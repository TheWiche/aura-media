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
import '../../../../shared/widgets/aura_logo.dart';
import '../../../downloader/data/models/download_task.dart';
import '../../../downloader/presentation/bloc/download_bloc.dart';
import '../../../downloader/presentation/bloc/download_event.dart';

/// Settings screen — Musicolet-style theme/AMOLED/accent customization,
/// dynamic logo recoloring, installed media player picker, separate folders & more.
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
  late bool _amoledDark;
  late AuraAccentPreset _accentPreset;
  late bool _reduceAnimations;

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

  String? _audioPlayerName;
  String? _videoPlayerName;

  String _audioDownloadPath = '';
  String _videoDownloadPath = '';
  bool _hasCustomAudioPath = false;
  bool _hasCustomVideoPath = false;

  bool _storagePermissionGranted = false;
  bool _batteryOptimizationIgnored = false;
  String _appVersion = '1.4.0+11';

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
    _amoledDark = s.getAmoledDark();
    _accentPreset = s.getAccentPreset();
    _reduceAnimations = s.getReduceAnimations();
    _audioPlayerName = s.getAudioPlayerName();
    _videoPlayerName = s.getVideoPlayerName();

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
      final results = await Future.wait<dynamic>([
        StorageService.instance.getDownloadDirectory(MediaType.audio),
        StorageService.instance.getDownloadDirectory(MediaType.video),
        PermissionService.instance.hasStoragePermission(),
        PermissionService.instance.isBatteryOptimizationIgnored(),
        NativePlatformService.instance.getAppVersion(),
      ]);

      if (!mounted) return;
      setState(() {
        _audioDownloadPath = (results[0] as Directory).path;
        _videoDownloadPath = (results[1] as Directory).path;
        _hasCustomAudioPath =
            SettingsService.instance.getAudioDownloadPath() != null;
        _hasCustomVideoPath =
            SettingsService.instance.getVideoDownloadPath() != null;
        _storagePermissionGranted = results[2] as bool;
        _batteryOptimizationIgnored = results[3] as bool;
        _appVersion = results[4] as String;
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

  Future<void> _pickMediaPlayer(MediaType mediaType) async {
    final tokens = AuraThemeTokens.of(context);
    final isAudio = mediaType == MediaType.audio;
    final currentPkg = isAudio
        ? SettingsService.instance.getAudioPlayerPackage()
        : SettingsService.instance.getVideoPlayerPackage();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _PlayerPickerSheet(
          mediaType: mediaType,
          selectedPackage: currentPkg,
          onSelect: (pkg, name) async {
            if (isAudio) {
              await SettingsService.instance.setAudioPlayer(
                packageName: pkg,
                appName: name,
              );
            } else {
              await SettingsService.instance.setVideoPlayer(
                packageName: pkg,
                appName: name,
              );
            }
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              _showSnack(
                name == null
                    ? 'Reproductor restablecido a sistema'
                    : 'Reproductor elegido: $name',
              );
            }
          },
        );
      },
    );
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
    final tokens = AuraThemeTokens.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Permiso de almacenamiento',
          style: AuraTypography.headingSmall
              .copyWith(color: tokens.textPrimary),
        ),
        content: Text(
          'Para guardar archivos MP3 y MP4 en carpetas personalizadas (como Music o Movies) en Android 11+, conviene activar "Acceso a todos los archivos".',
          style: AuraTypography.bodyMedium.copyWith(
            color: tokens.textSecondary,
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
    final tokens = AuraThemeTokens.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AuraTypography.bodyMedium.copyWith(
            color: isError ? tokens.error : tokens.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraDimensions.space5,
        vertical: AuraDimensions.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajustes',
            style: AuraTypography.headingLarge
                .copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: AuraDimensions.space1),
          Text(
            'Personaliza ${AppConstants.appName}, colores, reproductor y descargas.',
            style:
                AuraTypography.bodyMedium.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: AuraDimensions.space6),

          // ── Apariencia (estilo Musicolet: Tema + AMOLED + Color + Logo) ──
          const _SectionHeader(label: 'Apariencia'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: Column(
              children: [
                _DropdownRow<ThemeMode>(
                  icon: tokens.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  iconColor: tokens.primary,
                  title: 'Tema de la app',
                  subtitle: 'Claro, oscuro o automático del sistema',
                  value: widget.currentThemeMode,
                  items: const [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text('Sistema')),
                    DropdownMenuItem(
                        value: ThemeMode.dark, child: Text('Oscuro')),
                    DropdownMenuItem(
                        value: ThemeMode.light, child: Text('Claro')),
                  ],
                  onChanged: _onThemeModeChanged,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.contrast_rounded,
                    color: tokens.primary,
                  ),
                  title: Text(
                    'Negro puro (AMOLED)',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Fondo #000000 en modo oscuro para ahorrar batería',
                    style: AuraTypography.bodySmall
                        .copyWith(color: tokens.textSecondary),
                  ),
                  value: _amoledDark,
                  onChanged: (val) async {
                    await SettingsService.instance.setAmoledDark(val);
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                Padding(
                  padding: const EdgeInsets.all(AuraDimensions.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _IconBadge(
                            icon: Icons.palette_outlined,
                            color: tokens.primary,
                          ),
                          const SizedBox(width: AuraDimensions.space4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Color de acento y logotipo',
                                  style: AuraTypography.label.copyWith(
                                    fontSize: 15,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Activo: ${_accentPreset.label}',
                                  style: AuraTypography.bodySmall.copyWith(
                                    color: tokens.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const AuraLogo(size: 28),
                        ],
                      ),
                      const SizedBox(height: AuraDimensions.space3),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AuraAccentPreset.values.map((preset) {
                          final swatchColor = preset.primary(tokens.isDark);
                          final isSelected = preset == _accentPreset;
                          return Tooltip(
                            message: preset.label,
                            child: GestureDetector(
                              onTap: () async {
                                await SettingsService.instance
                                    .setAccentPreset(preset);
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: swatchColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? tokens.textPrimary
                                        : tokens.divider,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: preset.onPrimary(tokens.isDark),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.speed_rounded,
                    color: tokens.primary,
                  ),
                  title: Text(
                    'Reducir animaciones',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Transiciones instantáneas y más ligeras',
                    style: AuraTypography.bodySmall
                        .copyWith(color: tokens.textSecondary),
                  ),
                  value: _reduceAnimations,
                  onChanged: (val) async {
                    await SettingsService.instance.setReduceAnimations(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraDimensions.space6),

          // ── Reproductor predeterminado (apps instaladas) ──────────────────
          const _SectionHeader(label: 'Reproductor predeterminado'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  leading: _IconBadge(
                    icon: Icons.headphones_rounded,
                    color: tokens.audio,
                  ),
                  title: Text(
                    'Reproductor de Audio',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    _audioPlayerName ?? 'Predeterminado del sistema',
                    style: AuraTypography.bodySmall.copyWith(
                      color: _audioPlayerName != null
                          ? tokens.primary
                          : tokens.textSecondary,
                      fontWeight: _audioPlayerName != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: AuraDimensions.smallIconSize,
                    color: tokens.textSecondary,
                  ),
                  onTap: () => _pickMediaPlayer(MediaType.audio),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  leading: _IconBadge(
                    icon: Icons.smart_display_rounded,
                    color: tokens.video,
                  ),
                  title: Text(
                    'Reproductor de Video',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    _videoPlayerName ?? 'Predeterminado del sistema',
                    style: AuraTypography.bodySmall.copyWith(
                      color: _videoPlayerName != null
                          ? tokens.primary
                          : tokens.textSecondary,
                      fontWeight: _videoPlayerName != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: AuraDimensions.smallIconSize,
                    color: tokens.textSecondary,
                  ),
                  onTap: () => _pickMediaPlayer(MediaType.video),
                ),
              ],
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
                  iconColor: tokens.primary,
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
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                _DropdownRow<MediaType>(
                  icon: Icons.audiotrack_rounded,
                  iconColor: tokens.audio,
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
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.exit_to_app_rounded,
                    color: tokens.audio,
                  ),
                  title: Text(
                    'Cerrar modal al descargar',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Volver automáticamente a YouTube al iniciar',
                    style: AuraTypography.bodySmall
                        .copyWith(color: tokens.textSecondary),
                  ),
                  value: _autoCloseShareModal,
                  onChanged: (val) async {
                    await SettingsService.instance.setAutoCloseShareModal(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraDimensions.space6),

          // ── Carpetas de descarga ───────────────────────────────────────────
          const _SectionHeader(label: 'Carpetas de descarga'),
          const SizedBox(height: AuraDimensions.space2),
          AuraCard(
            child: Column(
              children: [
                _FolderTile(
                  icon: Icons.music_note_rounded,
                  iconColor: tokens.audio,
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
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                _FolderTile(
                  icon: Icons.videocam_rounded,
                  iconColor: tokens.video,
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
                  iconColor: tokens.video,
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
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                _DropdownRow<AudioFileFormat>(
                  icon: Icons.library_music_rounded,
                  iconColor: tokens.audio,
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
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                _DropdownRow<int>(
                  icon: Icons.sync_alt_rounded,
                  iconColor: tokens.primary,
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
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                _DropdownRow<DuplicateFilePolicy>(
                  icon: Icons.file_copy_outlined,
                  iconColor: tokens.warning,
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
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.person_outline_rounded,
                    color: tokens.primary,
                  ),
                  title: Text(
                    'Incluir autor en nombre',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Guardar como "Canal - Título"',
                    style: AuraTypography.bodySmall
                        .copyWith(color: tokens.textSecondary),
                  ),
                  value: _includeAuthor,
                  onChanged: (val) async {
                    await SettingsService.instance
                        .setIncludeAuthorInFilename(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.perm_media_outlined,
                    color: tokens.audio,
                  ),
                  title: Text(
                    'Indexar en Galería y Música',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Mostrar al instante en reproductores del sistema',
                    style: AuraTypography.bodySmall
                        .copyWith(color: tokens.textSecondary),
                  ),
                  value: _scanMediaLibrary,
                  onChanged: (val) async {
                    await SettingsService.instance.setScanMediaLibrary(val);
                    await BackgroundService.instance.notifySettingsUpdated();
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
                    color: tokens.video,
                  ),
                  title: Text(
                    'Solo descargar con Wi-Fi',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Pausa descargas si estás usando datos móviles',
                    style: AuraTypography.bodySmall
                        .copyWith(color: tokens.textSecondary),
                  ),
                  value: _wifiOnly,
                  onChanged: (val) async {
                    await SettingsService.instance.setWifiOnly(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  secondary: _IconBadge(
                    icon: Icons.history_rounded,
                    color: tokens.primary,
                  ),
                  title: Text(
                    'Conservar historial',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Mantener descargas completadas al reiniciar',
                    style: AuraTypography.bodySmall
                        .copyWith(color: tokens.textSecondary),
                  ),
                  value: _saveHistory,
                  onChanged: (val) async {
                    await SettingsService.instance.setSaveDownloadHistory(val);
                    await BackgroundService.instance.notifySettingsUpdated();
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  leading: _IconBadge(
                    icon: _storagePermissionGranted
                        ? Icons.verified_user_rounded
                        : Icons.folder_off_rounded,
                    color:
                        _storagePermissionGranted ? tokens.audio : tokens.warning,
                  ),
                  title: Text(
                    'Permiso de almacenamiento',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    _storagePermissionGranted
                        ? 'Concedido · Lectura y escritura lista'
                        : 'Toca para conceder acceso a carpetas',
                    style: AuraTypography.bodySmall.copyWith(
                      color: _storagePermissionGranted
                          ? tokens.audio
                          : tokens.warning,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: AuraDimensions.smallIconSize,
                    color: tokens.textSecondary,
                  ),
                  onTap: () async {
                    await PermissionService.instance
                        .requestManageExternalStorage();
                    await PermissionService.instance.requestStoragePermission();
                    await _loadPathsAndSystemStatus();
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: tokens.divider),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space4, vertical: 4),
                  leading: _IconBadge(
                    icon: Icons.battery_saver_rounded,
                    color: _batteryOptimizationIgnored
                        ? tokens.audio
                        : tokens.warning,
                  ),
                  title: Text(
                    'Segundo plano (Batería)',
                    style: AuraTypography.label
                        .copyWith(fontSize: 15, color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    _batteryOptimizationIgnored
                        ? 'Sin restricciones · Descargas largas protegidas'
                        : 'Toca para evitar cierres en segundo plano',
                    style: AuraTypography.bodySmall.copyWith(
                      color: _batteryOptimizationIgnored
                          ? tokens.audio
                          : tokens.warning,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: AuraDimensions.smallIconSize,
                    color: tokens.textSecondary,
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
              leading: const AuraLogo(size: 32),
              title: Text(
                AppConstants.appFullName,
                style: AuraTypography.label
                    .copyWith(fontSize: 15, color: tokens.textPrimary),
              ),
              subtitle: Text(
                'v$_appVersion · ${AppConstants.appTagline}',
                style: AuraTypography.metricSmall.copyWith(
                  color: tokens.textSecondary,
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

class _PlayerPickerSheet extends StatefulWidget {
  final MediaType mediaType;
  final String? selectedPackage;
  final Future<void> Function(String? packageName, String? appName) onSelect;

  const _PlayerPickerSheet({
    required this.mediaType,
    required this.selectedPackage,
    required this.onSelect,
  });

  @override
  State<_PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<_PlayerPickerSheet> {
  late final Future<List<InstalledMediaPlayer>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _playersFuture =
        NativePlatformService.instance.getInstalledMediaPlayers(widget.mediaType);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);
    final isAudio = widget.mediaType == MediaType.audio;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: tokens.divider,
                    borderRadius: AuraDimensions.radiusFull,
                  ),
                ),
              ),
              Text(
                isAudio ? 'Reproductor de Audio' : 'Reproductor de Video',
                style: AuraTypography.headingSmall
                    .copyWith(color: tokens.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Elige la app instalada con la que deseas abrir tus descargas.',
                style: AuraTypography.bodySmall
                    .copyWith(color: tokens.textSecondary),
              ),
              const SizedBox(height: AuraDimensions.space4),
              Flexible(
                child: FutureBuilder<List<InstalledMediaPlayer>>(
                  future: _playersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: tokens.primary,
                          ),
                        ),
                      );
                    }

                    final players = snapshot.data ?? const [];

                    return ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: tokens.primary.withValues(alpha: 0.14),
                              borderRadius: AuraDimensions.radiusSmall,
                            ),
                            child: Icon(
                              Icons.phone_android_rounded,
                              color: tokens.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Predeterminado del sistema',
                            style: AuraTypography.label
                                .copyWith(color: tokens.textPrimary),
                          ),
                          subtitle: Text(
                            'Usar selector o app por defecto de Android',
                            style: AuraTypography.bodySmall
                                .copyWith(color: tokens.textSecondary),
                          ),
                          trailing: widget.selectedPackage == null
                              ? Icon(Icons.check_circle_rounded,
                                  color: tokens.primary)
                              : null,
                          onTap: () => widget.onSelect(null, null),
                        ),
                        if (players.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No se detectaron otros reproductores instalados.',
                              style: AuraTypography.bodySmall
                                  .copyWith(color: tokens.textSecondary),
                            ),
                          ),
                        for (final player in players)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: AuraDimensions.radiusSmall,
                              child: player.iconBytes != null
                                  ? Image.memory(
                                      player.iconBytes!,
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 38,
                                      height: 38,
                                      color: tokens.card,
                                      child: Icon(
                                        isAudio
                                            ? Icons.music_note_rounded
                                            : Icons.videocam_rounded,
                                        color: tokens.primary,
                                      ),
                                    ),
                            ),
                            title: Text(
                              player.appName,
                              style: AuraTypography.label
                                  .copyWith(color: tokens.textPrimary),
                            ),
                            subtitle: Text(
                              player.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AuraTypography.metricSmall.copyWith(
                                fontSize: 11,
                                color: tokens.textSecondary,
                              ),
                            ),
                            trailing: widget.selectedPackage ==
                                    player.packageName
                                ? Icon(Icons.check_circle_rounded,
                                    color: tokens.primary)
                                : null,
                            onTap: () => widget.onSelect(
                              player.packageName,
                              player.appName,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);
    return Text(
      label.toUpperCase(),
      style: AuraTypography.bodySmall.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: tokens.primary,
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
    final tokens = AuraThemeTokens.of(context);

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
                      .copyWith(fontSize: 15, color: tokens.textPrimary),
                ),
                Text(
                  subtitle,
                  style: AuraTypography.bodySmall
                      .copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraDimensions.space2),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: tokens.surface,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: tokens.primary,
                size: AuraDimensions.smallIconSize,
              ),
              style: AuraTypography.label.copyWith(
                fontSize: 13,
                color: tokens.primary,
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
    final tokens = AuraThemeTokens.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraDimensions.space4, vertical: 6),
      leading: _IconBadge(icon: icon, color: iconColor),
      title: Text(
        title,
        style: AuraTypography.label
            .copyWith(fontSize: 15, color: tokens.textPrimary),
      ),
      subtitle: Text(
        path.isEmpty ? 'Cargando...' : path,
        style: AuraTypography.metricSmall.copyWith(
          fontSize: 11,
          color: tokens.textSecondary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReset != null)
            IconButton(
              icon: Icon(Icons.restore_rounded,
                  size: 19, color: tokens.textSecondary),
              tooltip: 'Restaurar predeterminada',
              onPressed: onReset,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: Icon(Icons.launch_rounded,
                size: 18, color: tokens.textSecondary),
            tooltip: 'Abrir carpeta',
            onPressed: onOpen,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 19, color: tokens.primary),
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
