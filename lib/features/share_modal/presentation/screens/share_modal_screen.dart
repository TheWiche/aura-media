import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/background_service.dart';
import '../../../../core/services/native_platform_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/share_intent_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_theme.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/aura_button.dart';
import '../../../../shared/widgets/aura_format_selector.dart';
import '../../../downloader/data/datasources/generic_extractor.dart';
import '../../../downloader/data/datasources/youtube_extractor.dart';
import '../../../downloader/data/models/download_task.dart';
import '../../../downloader/data/models/media_metadata.dart';

class ShareModalApp extends StatelessWidget {
  final ThemeMode initialThemeMode;

  const ShareModalApp({super.key, required this.initialThemeMode});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura Descarga Rápida',
      debugShowCheckedModeBanner: false,
      theme: AuraTheme.light.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      darkTheme: AuraTheme.dark.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      themeMode: initialThemeMode,
      color: Colors.transparent,
      home: const ShareModalScreen(),
    );
  }
}

class ShareModalScreen extends StatefulWidget {
  final String? initialSharedText;
  final YoutubeExtractor? youtubeExtractor;
  final GenericExtractor? genericExtractor;
  final Future<void> Function(DownloadTask task)? onEnqueueTask;
  final VoidCallback? onClose;
  final Future<void> Function(String? url)? onOpenMainApp;

  const ShareModalScreen({
    super.key,
    this.initialSharedText,
    this.youtubeExtractor,
    this.genericExtractor,
    this.onEnqueueTask,
    this.onClose,
    this.onOpenMainApp,
  });

  @override
  State<ShareModalScreen> createState() => _ShareModalScreenState();
}

class _ShareModalScreenState extends State<ShareModalScreen>
    with SingleTickerProviderStateMixin {
  late final YoutubeExtractor _youtubeExtractor;
  late final GenericExtractor _genericExtractor;
  final Uuid _uuid = const Uuid();

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String? _resolvedUrl;
  MediaMetadata? _metadata;
  bool _isLoadingMetadata = false;
  bool _isSubmitting = false;
  bool _queuedSuccess = false;
  bool _isAutoDownloading = false;
  String? _error;

  late MediaType _selectedMediaType;
  late VideoQuality _selectedQuality;
  late AudioFileFormat _audioFormat;
  String _audioFolderLabel = 'Download/AuraMedia/Audio';
  String _videoFolderLabel = 'Download/AuraMedia/Video';

  Completer<MediaMetadata?>? _metadataCompleter;

  @override
  void initState() {
    super.initState();
    _youtubeExtractor = widget.youtubeExtractor ?? YoutubeExtractor();
    _genericExtractor = widget.genericExtractor ?? GenericExtractor();

    _selectedMediaType = SettingsService.instance.getDefaultMediaType();
    _selectedQuality = SettingsService.instance.getDefaultQuality();
    _audioFormat = SettingsService.instance.getAudioFormat();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
    _loadFolderLabels();

    NativePlatformService.instance.setNewShareHandler((text) {
      if (mounted) {
        _processIncomingSharedText(text);
      }
    });

    _bootstrapInitialShare();
  }

  Future<void> _loadFolderLabels() async {
    try {
      final audioDir = await StorageService.instance.getDownloadDirectory(
        MediaType.audio,
      );
      final videoDir = await StorageService.instance.getDownloadDirectory(
        MediaType.video,
      );
      if (mounted) {
        setState(() {
          _audioFolderLabel = _compactPath(audioDir.path);
          _videoFolderLabel = _compactPath(videoDir.path);
        });
      }
    } catch (_) {}
  }

  String _compactPath(String fullPath) {
    final normalized = fullPath.replaceAll('\\', '/');
    const emulatedPrefix = '/storage/emulated/0/';
    if (normalized.startsWith(emulatedPrefix)) {
      return normalized.substring(emulatedPrefix.length);
    }
    final segments =
        normalized.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 3) return normalized;
    return '.../${segments.sublist(segments.length - 2).join('/')}';
  }

  Future<void> _bootstrapInitialShare() async {
    final raw = widget.initialSharedText ??
        await NativePlatformService.instance.getSharePayload();
    if (!mounted) return;
    await _processIncomingSharedText(raw);
  }

  Future<void> _processIncomingSharedText(String? rawText) async {
    final url = rawText == null
        ? null
        : ShareIntentService.extractUrlFromText(rawText);

    if (url == null || url.isEmpty) {
      setState(() {
        _resolvedUrl = null;
        _isLoadingMetadata = false;
        _error = 'No se encontró un enlace válido en el texto compartido.';
      });
      return;
    }

    final behavior = SettingsService.instance.getShareBehavior();
    if (behavior == ShareBehavior.openApp) {
      await _openInFullApp(url);
      return;
    }

    setState(() {
      _resolvedUrl = url;
      _error = null;
      _queuedSuccess = false;
    });

    if (behavior == ShareBehavior.autoDownload) {
      await _runInstantAutoDownload(url);
      return;
    }

    await _fetchMetadata(url);
  }

  Future<void> _runInstantAutoDownload(String url) async {
    setState(() {
      _isAutoDownloading = true;
      _isLoadingMetadata = true;
    });

    MediaMetadata? meta;
    try {
      meta = await _loadMetadataDirect(url).timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (!mounted) return;

    await _enqueueAndHandleClose(
      url: url,
      metadata: meta,
      forceAutoClose: true,
    );
  }

  Future<MediaMetadata?> _loadMetadataDirect(String url) async {
    if (YoutubeExtractor.isYoutubeUrl(url)) {
      return _youtubeExtractor.fetchMetadata(url);
    }
    return _genericExtractor.fetchMetadata(url);
  }

  Future<void> _fetchMetadata(String url) async {
    final completer = Completer<MediaMetadata?>();
    _metadataCompleter = completer;

    setState(() {
      _isLoadingMetadata = true;
      _metadata = null;
      _error = null;
    });

    try {
      final meta = await _loadMetadataDirect(url);
      if (!completer.isCompleted) completer.complete(meta);
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _metadata = meta;
      });
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _isLoadingMetadata = false;
        _error = cleanMsg;
      });
    }
  }

  Future<void> _handleDownloadPressed() async {
    final url = _resolvedUrl;
    if (url == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    MediaMetadata? meta = _metadata;
    if (meta == null && _isLoadingMetadata && _metadataCompleter != null) {
      try {
        meta = await _metadataCompleter!.future
            .timeout(const Duration(seconds: 6), onTimeout: () => null);
      } catch (_) {}
    }

    if (!mounted) return;
    await _enqueueAndHandleClose(url: url, metadata: meta);
  }

  Future<void> _enqueueAndHandleClose({
    required String url,
    required MediaMetadata? metadata,
    bool? forceAutoClose,
  }) async {
    if (widget.onEnqueueTask == null) {
      await PermissionService.instance.requestStoragePermission();
      await PermissionService.instance.requestNotificationPermission();
    }

    final taskId = _uuid.v4();
    final notifId = taskId.hashCode.abs() % 100000;
    final audioExt = _audioFormat.name;
    final extension = _selectedMediaType == MediaType.audio ? audioExt : 'mp4';

    final title = metadata?.title ??
        'Descarga_${DateTime.now().millisecondsSinceEpoch}';
    final initialTotalBytes = _selectedMediaType == MediaType.audio
        ? (metadata?.audioSizeBytes ?? 0)
        : (metadata?.videoSizeBytes ?? 0);

    final task = DownloadTask(
      id: taskId,
      notificationId: notifId,
      url: url,
      title: title,
      author: metadata?.author,
      thumbnailUrl: metadata?.thumbnailUrl,
      mediaType: _selectedMediaType,
      quality: _selectedQuality,
      fileExtension: extension,
      totalBytes: initialTotalBytes,
      createdAt: DateTime.now(),
      status: DownloadStatus.queued,
    );

    if (widget.onEnqueueTask != null) {
      await widget.onEnqueueTask!(task);
    } else {
      await BackgroundService.instance.enqueueTask(task);
    }

    if (!mounted) return;

    final shouldClose =
        forceAutoClose ?? SettingsService.instance.getAutoCloseShareModal();

    if (shouldClose) {
      setState(() {
        _isSubmitting = false;
        _queuedSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 320));
      await _closeModal();
    } else {
      setState(() {
        _isSubmitting = false;
        _queuedSuccess = true;
      });
    }
  }

  Future<void> _closeModal() async {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    await _animController.reverse();
    await NativePlatformService.instance.closeShareModal();
  }

  Future<void> _openInFullApp(String? url) async {
    if (widget.onOpenMainApp != null) {
      await widget.onOpenMainApp!(url);
      return;
    }
    await NativePlatformService.instance.openMainApp(url: url);
  }

  @override
  void dispose() {
    _animController.dispose();
    if (widget.youtubeExtractor == null) {
      _youtubeExtractor.close();
    }
    if (widget.genericExtractor == null) {
      _genericExtractor.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalSurface = isDark
        ? AuraColors.darkSurface.withValues(alpha: 0.97)
        : AuraColors.lightSurface.withValues(alpha: 0.98);
    final cardBg = AuraColors.card(isDark);
    final dividerColor = AuraColors.divider(isDark);
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);

    final qualities = _metadata?.availableQualities ??
        const [
          VideoQuality.best,
          VideoQuality.p1080,
          VideoQuality.p720,
          VideoQuality.p480,
          VideoQuality.p360,
        ];
    final effectiveQuality =
        qualities.contains(_selectedQuality) ? _selectedQuality : qualities.first;

    final audioExtUpper = _audioFormat.name.toUpperCase();
    final activeFolder = _selectedMediaType == MediaType.audio
        ? _audioFolderLabel
        : _videoFolderLabel;

    final buttonLabel = _selectedMediaType == MediaType.audio
        ? 'Descargar Audio ($audioExtUpper)'
        : 'Descargar Video (${_shortQualityLabel(effectiveQuality)})';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeModal,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Material(
                    color: Colors.transparent,
                    elevation: AuraDimensions.modalElevation,
                    borderRadius: AuraDimensions.radiusExtraLarge,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                      padding: const EdgeInsets.all(AuraDimensions.space5),
                      decoration: BoxDecoration(
                        color: modalSurface,
                        borderRadius: AuraDimensions.radiusExtraLarge,
                        border: Border.all(color: dividerColor, width: 1),
                      ),
                      child: _isAutoDownloading
                          ? _buildAutoDownloadingBanner(textPrimary, isDark)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Drag handle
                                Center(
                                  child: Container(
                                    width: 36,
                                    height: 4,
                                    margin: const EdgeInsets.only(
                                        bottom: AuraDimensions.space3),
                                    decoration: BoxDecoration(
                                      color: dividerColor,
                                      borderRadius: AuraDimensions.radiusFull,
                                    ),
                                  ),
                                ),

                                // Header with Aura brand mark
                                Row(
                                  children: [
                                    Image.asset(
                                      'assets/icon/aura_logo.png',
                                      width: 26,
                                      height: 26,
                                    ),
                                    const SizedBox(width: AuraDimensions.space2),
                                    Expanded(
                                      child: Text(
                                        'Aura',
                                        style: AuraTypography.headingSmall
                                            .copyWith(color: textPrimary),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _openInFullApp(_resolvedUrl),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Abrir app',
                                        style: AuraTypography.label.copyWith(
                                          fontSize: 12,
                                          color: AuraColors.primary(isDark),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AuraDimensions.space1),
                                    IconButton(
                                      onPressed: _closeModal,
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: AuraDimensions.smallIconSize,
                                        color: textSecondary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AuraDimensions.space4),

                                // Media preview (88x88 thumbnail per Section 8)
                                if (_metadata != null)
                                  _buildCompactPreview(
                                    _metadata!,
                                    cardBg,
                                    textPrimary,
                                    textSecondary,
                                    dividerColor,
                                    isDark,
                                  )
                                else if (_isLoadingMetadata)
                                  _buildLoadingPreview(
                                      cardBg, textSecondary, dividerColor, isDark)
                                else if (_error != null)
                                  _buildErrorBanner(isDark),

                                const SizedBox(height: AuraDimensions.space4),

                                // Format selector (Audio green / Video violet)
                                AuraFormatSelector(
                                  selectedMediaType: _selectedMediaType,
                                  selectedQuality: effectiveQuality,
                                  availableQualities: qualities,
                                  audioSizeBytes: _metadata?.audioSizeBytes,
                                  videoSizeBytes: _metadata?.videoSizeBytes,
                                  audioExtensionLabel: audioExtUpper,
                                  compact: true,
                                  onMediaTypeChanged: (type) =>
                                      setState(() => _selectedMediaType = type),
                                  onQualityChanged: (q) =>
                                      setState(() => _selectedQuality = q),
                                ),

                                const SizedBox(height: AuraDimensions.space4),

                                // Action button
                                if (_queuedSuccess)
                                  Container(
                                    height: AuraDimensions.buttonHeight,
                                    decoration: BoxDecoration(
                                      color: AuraColors.audio(isDark)
                                          .withValues(alpha: 0.16),
                                      borderRadius: AuraDimensions.radiusMedium,
                                      border: Border.all(
                                        color: AuraColors.audio(isDark)
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: AuraColors.audio(isDark),
                                          size: 20,
                                        ),
                                        const SizedBox(
                                            width: AuraDimensions.space2),
                                        Text(
                                          '¡Descarga iniciada en segundo plano!',
                                          style: AuraTypography.button.copyWith(
                                            color: AuraColors.audio(isDark),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  AuraButton(
                                    label: _isSubmitting
                                        ? 'Preparando descarga...'
                                        : buttonLabel,
                                    icon: Icons.download_rounded,
                                    isLoading: _isSubmitting,
                                    onPressed: _resolvedUrl == null
                                        ? null
                                        : _handleDownloadPressed,
                                  ),

                                const SizedBox(height: AuraDimensions.space3),

                                // Local destination folder footer
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Guardado local · $activeFolder',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AuraTypography.bodySmall.copyWith(
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoDownloadingBanner(Color textPrimary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraDimensions.space3),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AuraColors.primary(isDark),
            ),
          ),
          const SizedBox(width: AuraDimensions.space3),
          Expanded(
            child: Text(
              _queuedSuccess
                  ? '¡Descarga iniciada en segundo plano!'
                  : 'Iniciando descarga automática...',
              style: AuraTypography.label.copyWith(
                fontSize: 14,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPreview(
    MediaMetadata meta,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color dividerColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AuraDimensions.space3),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AuraDimensions.radiusLarge,
        border: Border.all(color: dividerColor, width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AuraDimensions.radiusMedium,
            child: Container(
              width: 88,
              height: 88,
              color: AuraColors.primary(isDark).withValues(alpha: 0.12),
              child: meta.thumbnailUrl != null
                  ? Image.network(
                      meta.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.play_circle_outline_rounded,
                        color: AuraColors.primary(isDark),
                        size: 30,
                      ),
                    )
                  : Icon(
                      Icons.play_circle_outline_rounded,
                      color: AuraColors.primary(isDark),
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: AuraDimensions.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuraTypography.headingSmall.copyWith(
                    fontSize: 15,
                    color: textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space1),
                Text(
                  meta.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraTypography.bodySmall.copyWith(
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space2),
                Row(
                  children: [
                    if (meta.duration != null) ...[
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        Formatters.formatDuration(meta.duration!),
                        style: AuraTypography.metricSmall.copyWith(
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: AuraDimensions.space2),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AuraColors.primary(isDark)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meta.platform,
                        style: AuraTypography.bodySmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AuraColors.primary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPreview(
    Color cardBg,
    Color textSecondary,
    Color dividerColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AuraDimensions.space4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AuraDimensions.radiusLarge,
        border: Border.all(color: dividerColor, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AuraColors.primary(isDark),
            ),
          ),
          const SizedBox(width: AuraDimensions.space3),
          Expanded(
            child: Text(
              'Obteniendo detalles del enlace...',
              style: AuraTypography.bodyMedium.copyWith(color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    final errColor = AuraColors.error(isDark);
    return Container(
      padding: const EdgeInsets.all(AuraDimensions.space3),
      decoration: BoxDecoration(
        color: errColor.withValues(alpha: 0.1),
        borderRadius: AuraDimensions.radiusMedium,
        border: Border.all(color: errColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: errColor, size: 18),
          const SizedBox(width: AuraDimensions.space2),
          Expanded(
            child: Text(
              _error!,
              style: AuraTypography.bodySmall.copyWith(
                color: errColor,
                height: 1.35,
              ),
            ),
          ),
          if (_resolvedUrl != null)
            TextButton(
              onPressed: () => _fetchMetadata(_resolvedUrl!),
              child: Text(
                'Reintentar',
                style: AuraTypography.label.copyWith(
                  fontSize: 12,
                  color: AuraColors.primary(isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortQualityLabel(VideoQuality quality) {
    return switch (quality) {
      VideoQuality.best => 'Mejor',
      VideoQuality.p1080 => '1080p',
      VideoQuality.p720 => '720p',
      VideoQuality.p480 => '480p',
      VideoQuality.p360 => '360p',
    };
  }
}
