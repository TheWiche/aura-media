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
import '../../../../shared/widgets/aura_logo.dart';
import '../../../downloader/data/datasources/generic_extractor.dart';
import '../../../downloader/data/datasources/youtube_extractor.dart';
import '../../../downloader/data/models/download_task.dart';
import '../../../downloader/data/models/media_metadata.dart';

class ShareModalApp extends StatelessWidget {
  final ThemeMode initialThemeMode;

  const ShareModalApp({super.key, required this.initialThemeMode});

  @override
  Widget build(BuildContext context) {
    final amoled = SettingsService.instance.getAmoledDark();
    final accent = SettingsService.instance.getAccentPreset();
    final reduceAnimations = SettingsService.instance.getReduceAnimations();

    return MaterialApp(
      title: 'Aura Descarga Rápida',
      debugShowCheckedModeBanner: false,
      theme: AuraTheme.buildLight(
        accent: accent,
        reduceAnimations: reduceAnimations,
      ).copyWith(scaffoldBackgroundColor: Colors.transparent),
      darkTheme: AuraTheme.buildDark(
        amoled: amoled,
        accent: accent,
        reduceAnimations: reduceAnimations,
      ).copyWith(scaffoldBackgroundColor: Colors.transparent),
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
  late VideoFormatPreference _videoFormatPref;
  VideoStreamOption? _selectedVideoOption;
  AudioStreamOption? _selectedAudioOption;

  String _audioFolderLabel = 'Download/AuraMedia/Audio';
  String _videoFolderLabel = 'Download/AuraMedia/Video';

  Completer<MediaMetadata?>? _metadataCompleter;
  int _analysisGeneration = 0;

  @override
  void initState() {
    super.initState();
    _youtubeExtractor = widget.youtubeExtractor ?? YoutubeExtractor();
    _genericExtractor = widget.genericExtractor ?? GenericExtractor();

    _selectedMediaType = SettingsService.instance.getDefaultMediaType();
    _selectedQuality = SettingsService.instance.getDefaultQuality();
    _audioFormat = SettingsService.instance.getAudioFormat();
    _videoFormatPref = SettingsService.instance.getDefaultVideoFormat();
    final reduceAnimations = SettingsService.instance.getReduceAnimations();

    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduceAnimations ? 0 : 120),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
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
      final results = await Future.wait([
        StorageService.instance.getDownloadDirectory(MediaType.audio),
        StorageService.instance.getDownloadDirectory(MediaType.video),
      ]);
      if (mounted) {
        setState(() {
          _audioFolderLabel = _compactPath(results[0].path);
          _videoFolderLabel = _compactPath(results[1].path);
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
      _selectedVideoOption = null;
      _selectedAudioOption = null;
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
    final generation = ++_analysisGeneration;

    setState(() {
      _isLoadingMetadata = true;
      _metadata = null;
      _error = null;
    });

    try {
      MediaMetadata meta;
      if (YoutubeExtractor.isYoutubeUrl(url)) {
        meta = await _youtubeExtractor.fetchMetadataProgressive(
          url,
          onProgress: (partial) {
            if (!mounted || generation != _analysisGeneration) return;
            setState(() {
              _metadata = partial;
              _isLoadingMetadata = !partial.analysisStage.hasStreams;
            });
            if (partial.analysisStage.hasStreams && !completer.isCompleted) {
              completer.complete(partial);
            }
          },
        );
      } else {
        meta = await _genericExtractor.fetchMetadata(url);
      }

      if (!completer.isCompleted) completer.complete(meta);
      if (!mounted || generation != _analysisGeneration) return;
      setState(() {
        _isLoadingMetadata = false;
        _metadata = meta;
      });
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      if (!mounted || generation != _analysisGeneration) return;
      final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _isLoadingMetadata = false;
        _metadata = null;
        _error = cleanMsg;
      });
    }
  }

  VideoStreamOption? _activeVideoOption(MediaMetadata? meta) {
    if (meta == null || meta.videoOptions.isEmpty) return null;
    if (_selectedVideoOption != null &&
        meta.videoOptions.any((o) => o.id == _selectedVideoOption!.id)) {
      return _selectedVideoOption;
    }
    return meta.bestVideoOptionFor(_selectedQuality, _videoFormatPref);
  }

  AudioStreamOption? _activeAudioOption(MediaMetadata? meta) {
    if (meta == null || meta.audioOptions.isEmpty) return null;
    if (_selectedAudioOption != null &&
        _selectedAudioOption!.format == _audioFormat &&
        meta.audioOptions.any((o) => o.id == _selectedAudioOption!.id)) {
      return _selectedAudioOption;
    }
    return meta.bestAudioOptionFor(_audioFormat);
  }

  Future<void> _handleDownloadPressed() async {
    final url = _resolvedUrl;
    if (url == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    MediaMetadata? meta = _metadata;
    if ((meta == null || !meta.analysisStage.hasBasicInfo) &&
        _isLoadingMetadata &&
        _metadataCompleter != null) {
      try {
        final completed = await _metadataCompleter!.future
            .timeout(const Duration(seconds: 6), onTimeout: () => _metadata);
        if (completed != null) meta = completed;
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

    final videoOpt = _activeVideoOption(metadata);
    final audioOpt = _activeAudioOption(metadata);

    final effectiveExt = _selectedMediaType == MediaType.audio
        ? (audioOpt?.extension ?? _audioFormat.extensionName)
        : (videoOpt?.container ?? 'mp4');

    final effectiveQuality = _selectedMediaType == MediaType.video
        ? (videoOpt?.quality ?? _selectedQuality)
        : _selectedQuality;

    final specSummary = _selectedMediaType == MediaType.audio
        ? audioOpt?.specSummary
        : videoOpt?.specSummary;

    final title = metadata?.title ??
        'Descarga_${DateTime.now().millisecondsSinceEpoch}';
    final initialTotalBytes = _selectedMediaType == MediaType.audio
        ? (audioOpt?.sizeBytes ?? metadata?.audioSizeBytes ?? 0)
        : (videoOpt?.totalSizeBytes ?? metadata?.videoSizeBytes ?? 0);

    final task = DownloadTask(
      id: taskId,
      notificationId: notifId,
      url: url,
      title: title,
      author: metadata?.author,
      thumbnailUrl: metadata?.thumbnailUrl,
      mediaType: _selectedMediaType,
      quality: effectiveQuality,
      fileExtension: effectiveExt,
      videoItag: _selectedMediaType == MediaType.video
          ? videoOpt?.videoItag
          : null,
      audioItag: _selectedMediaType == MediaType.audio
          ? audioOpt?.itag
          : videoOpt?.audioItag,
      audioLanguage: audioOpt?.trackLanguage,
      specSummary: specSummary,
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
      await Future.delayed(const Duration(milliseconds: 220));
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
    if (!SettingsService.instance.getReduceAnimations()) {
      await _animController.reverse();
    }
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
    final tokens = AuraThemeTokens.of(context);
    final modalSurface = tokens.surface.withValues(alpha: 0.97);
    final maxModalHeight = MediaQuery.sizeOf(context).height * 0.92;

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

    final activeVideoOpt = _activeVideoOption(_metadata);
    final activeAudioOpt = _activeAudioOption(_metadata);

    final audioExtUpper =
        activeAudioOpt?.extension.toUpperCase() ?? _audioFormat.shortLabel;
    final activeFolder = _selectedMediaType == MediaType.audio
        ? _audioFolderLabel
        : _videoFolderLabel;

    final buttonLabel = _selectedMediaType == MediaType.audio
        ? (activeAudioOpt != null
            ? 'Descargar Audio ($audioExtUpper · ${activeAudioOpt.bitrateKbps}k)'
            : 'Descargar Audio ($audioExtUpper)')
        : (activeVideoOpt != null
            ? 'Descargar Video (${activeVideoOpt.resolutionTag} ${activeVideoOpt.container.toUpperCase()})'
            : 'Descargar Video (${effectiveQuality.shortLabel})');

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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxModalHeight),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: BoxDecoration(
                        color: modalSurface,
                        borderRadius: AuraDimensions.radiusExtraLarge,
                        border: Border.all(color: tokens.divider, width: 1),
                      ),
                      child: _isAutoDownloading
                          ? _buildAutoDownloadingBanner(tokens)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 36,
                                    height: 4,
                                    margin: const EdgeInsets.only(
                                        bottom: AuraDimensions.space3),
                                    decoration: BoxDecoration(
                                      color: tokens.divider,
                                      borderRadius: AuraDimensions.radiusFull,
                                    ),
                                  ),
                                ),

                                Row(
                                  children: [
                                    const AuraLogo(size: 26),
                                    const SizedBox(width: AuraDimensions.space2),
                                    Expanded(
                                      child: Text(
                                        'Aura',
                                        style: AuraTypography.headingSmall
                                            .copyWith(color: tokens.textPrimary),
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
                                          color: tokens.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AuraDimensions.space1),
                                    IconButton(
                                      onPressed: _closeModal,
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: AuraDimensions.smallIconSize,
                                        color: tokens.textSecondary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AuraDimensions.space3),

                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_metadata != null)
                                          _buildCompactPreview(
                                            _metadata!,
                                            tokens,
                                          )
                                        else if (_isLoadingMetadata)
                                          _buildLoadingPreview(tokens)
                                        else if (_error != null)
                                          _buildErrorBanner(tokens),

                                        const SizedBox(
                                            height: AuraDimensions.space4),

                                        AuraFormatSelector(
                                          selectedMediaType:
                                              _selectedMediaType,
                                          selectedQuality: effectiveQuality,
                                          availableQualities: qualities,
                                          audioSizeBytes:
                                              _metadata?.audioSizeBytes,
                                          videoSizeBytes:
                                              _metadata?.videoSizeBytes,
                                          audioExtensionLabel: audioExtUpper,
                                          compact: true,
                                          videoOptions:
                                              _metadata?.videoOptions ??
                                                  const [],
                                          selectedVideoOption: activeVideoOpt,
                                          onVideoOptionChanged: (opt) =>
                                              setState(() {
                                            _selectedVideoOption = opt;
                                            _selectedQuality = opt.quality;
                                          }),
                                          audioOptions:
                                              _metadata?.audioOptions ??
                                                  const [],
                                          selectedAudioOption: activeAudioOpt,
                                          onAudioOptionChanged: (opt) =>
                                              setState(() {
                                            _selectedAudioOption = opt;
                                            _audioFormat = opt.format;
                                          }),
                                          selectedAudioFormat: _audioFormat,
                                          onAudioFormatChanged: (fmt) =>
                                              setState(() {
                                            _audioFormat = fmt;
                                            _selectedAudioOption = _metadata
                                                ?.bestAudioOptionFor(fmt);
                                          }),
                                          isResolvingFormats:
                                              _metadata != null &&
                                                  !_metadata!
                                                      .analysisStage.hasStreams,
                                          onMediaTypeChanged: (type) =>
                                              setState(() =>
                                                  _selectedMediaType = type),
                                          onQualityChanged: (q) =>
                                              setState(() {
                                            _selectedQuality = q;
                                            _selectedVideoOption = _metadata
                                                ?.bestVideoOptionFor(
                                              q,
                                              _videoFormatPref,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AuraDimensions.space4),

                                if (_queuedSuccess)
                                  Container(
                                    height: AuraDimensions.buttonHeight,
                                    decoration: BoxDecoration(
                                      color:
                                          tokens.audio.withValues(alpha: 0.16),
                                      borderRadius: AuraDimensions.radiusMedium,
                                      border: Border.all(
                                        color:
                                            tokens.audio.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: tokens.audio,
                                          size: 20,
                                        ),
                                        const SizedBox(
                                            width: AuraDimensions.space2),
                                        Text(
                                          '¡Descarga iniciada en segundo plano!',
                                          style: AuraTypography.button.copyWith(
                                            color: tokens.audio,
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

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: tokens.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Guardado local · $activeFolder',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AuraTypography.bodySmall.copyWith(
                                          color: tokens.textSecondary,
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

  Widget _buildAutoDownloadingBanner(AuraThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraDimensions.space3),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: tokens.primary,
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
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPreview(MediaMetadata meta, AuraThemeTokens tokens) {
    final stageHint = switch (meta.analysisStage) {
      AnalysisStage.instant => 'Conectando...',
      AnalysisStage.basicInfo => 'Cargando calidades...',
      AnalysisStage.streamsReady || AnalysisStage.enriching => 'Refinando...',
      AnalysisStage.complete => null,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: AuraDimensions.radiusLarge,
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AuraDimensions.radiusMedium,
            child: Container(
              width: 72,
              height: 72,
              color: tokens.primary.withValues(alpha: 0.12),
              child: meta.thumbnailUrl != null
                  ? Image.network(
                      meta.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.play_circle_outline_rounded,
                        color: tokens.primary,
                        size: 30,
                      ),
                    )
                  : Icon(
                      Icons.play_circle_outline_rounded,
                      color: tokens.primary,
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
                    color: tokens.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space1),
                Text(
                  meta.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraTypography.bodySmall.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space2),
                Wrap(
                  spacing: AuraDimensions.space2,
                  runSpacing: AuraDimensions.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (meta.duration != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            Formatters.formatDuration(meta.duration!),
                            style: AuraTypography.metricSmall.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meta.platform,
                        style: AuraTypography.bodySmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: tokens.primary,
                        ),
                      ),
                    ),
                    if (stageHint != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: tokens.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stageHint,
                            style: AuraTypography.bodySmall.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.primary,
                            ),
                          ),
                        ],
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

  Widget _buildLoadingPreview(AuraThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(AuraDimensions.space4),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: AuraDimensions.radiusLarge,
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.primary,
            ),
          ),
          const SizedBox(width: AuraDimensions.space3),
          Expanded(
            child: Text(
              'Obteniendo detalles del enlace...',
              style: AuraTypography.bodyMedium
                  .copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(AuraThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(AuraDimensions.space3),
      decoration: BoxDecoration(
        color: tokens.error.withValues(alpha: 0.1),
        borderRadius: AuraDimensions.radiusMedium,
        border: Border.all(color: tokens.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: tokens.error, size: 18),
          const SizedBox(width: AuraDimensions.space2),
          Expanded(
            child: Text(
              _error!,
              style: AuraTypography.bodySmall.copyWith(
                color: tokens.error,
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
                  color: tokens.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
