import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../shared/widgets/aura_button.dart';
import '../../../../shared/widgets/aura_card.dart';
import '../../../../shared/widgets/aura_format_selector.dart';
import '../../data/datasources/youtube_extractor.dart';
import '../../data/models/download_task.dart';
import '../../data/models/media_metadata.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import '../widgets/media_preview_card.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToQueue;
  final String? initialUrl;

  const HomeTab({
    super.key,
    required this.onNavigateToQueue,
    this.initialUrl,
  });

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final TextEditingController _urlController = TextEditingController();
  late MediaType _selectedMediaType;
  late VideoQuality _selectedQuality;
  late AudioFileFormat _selectedAudioFormat;
  late VideoFormatPreference _selectedVideoFormatPref;

  VideoStreamOption? _selectedVideoOption;
  AudioStreamOption? _selectedAudioOption;
  String? _lastUrlForOptions;

  @override
  void initState() {
    super.initState();
    _syncFromSettings();
    SettingsService.instance.changesNotifier.addListener(_onSettingsChanged);

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleIncomingUrl(widget.initialUrl!);
      });
    }
  }

  void _syncFromSettings() {
    final s = SettingsService.instance;
    _selectedMediaType = s.getDefaultMediaType();
    _selectedQuality = s.getDefaultQuality();
    _selectedAudioFormat = s.getAudioFormat();
    _selectedVideoFormatPref = s.getDefaultVideoFormat();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _syncFromSettings();
    });
  }

  @override
  void dispose() {
    SettingsService.instance.changesNotifier.removeListener(_onSettingsChanged);
    _urlController.dispose();
    super.dispose();
  }

  /// Called externally by ShareIntentService or internal shortcuts
  void handleIncomingUrl(String url) {
    final clean = YoutubeExtractor.cleanUrl(url);
    _urlController.text = clean;
    if (mounted) {
      setState(() {
        _selectedVideoOption = null;
        _selectedAudioOption = null;
        _lastUrlForOptions = clean;
      });
      _fetchMetadata();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      handleIncomingUrl(text);
    }
  }

  void _fetchMetadata() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _selectedVideoOption = null;
        _selectedAudioOption = null;
        _lastUrlForOptions = text;
      });
      context.read<DownloadBloc>().add(FetchMetadataEvent(text));
    }
  }

  VideoStreamOption? _activeVideoOption(MediaMetadata? meta) {
    if (meta == null || meta.videoOptions.isEmpty) return null;
    if (_selectedVideoOption != null &&
        meta.videoOptions.any((o) => o.id == _selectedVideoOption!.id)) {
      return _selectedVideoOption;
    }
    return meta.bestVideoOptionFor(_selectedQuality, _selectedVideoFormatPref);
  }

  AudioStreamOption? _activeAudioOption(MediaMetadata? meta) {
    if (meta == null || meta.audioOptions.isEmpty) return null;
    if (_selectedAudioOption != null &&
        _selectedAudioOption!.format == _selectedAudioFormat &&
        meta.audioOptions.any((o) => o.id == _selectedAudioOption!.id)) {
      return _selectedAudioOption;
    }
    return meta.bestAudioOptionFor(_selectedAudioFormat);
  }

  void _addToQueue(DownloadState state) {
    final url = _urlController.text.trim();
    final meta = state.previewMetadata;
    if (url.isEmpty || meta == null) return;

    final videoOpt = _activeVideoOption(meta);
    final audioOpt = _activeAudioOption(meta);

    final effectiveExt = _selectedMediaType == MediaType.audio
        ? (audioOpt?.extension ?? _selectedAudioFormat.extensionName)
        : (videoOpt?.container ?? 'mp4');

    final effectiveQuality = _selectedMediaType == MediaType.video
        ? (videoOpt?.quality ?? _selectedQuality)
        : _selectedQuality;

    final specSummary = _selectedMediaType == MediaType.audio
        ? audioOpt?.specSummary
        : videoOpt?.specSummary;

    final estimatedBytes = _selectedMediaType == MediaType.audio
        ? (audioOpt?.sizeBytes ?? meta.audioSizeBytes)
        : (videoOpt?.totalSizeBytes ?? meta.videoSizeBytes);

    context.read<DownloadBloc>().add(
          EnqueueDownloadEvent(
            url: url,
            mediaType: _selectedMediaType,
            quality: effectiveQuality,
            metadata: meta,
            fileExtension: effectiveExt,
            videoItag: _selectedMediaType == MediaType.video
                ? videoOpt?.videoItag
                : null,
            audioItag: _selectedMediaType == MediaType.audio
                ? audioOpt?.itag
                : videoOpt?.audioItag,
            audioLanguage: audioOpt?.trackLanguage,
            specSummary: specSummary,
            estimatedTotalBytes: estimatedBytes,
          ),
        );

    _urlController.clear();
    _selectedVideoOption = null;
    _selectedAudioOption = null;
    context.read<DownloadBloc>().add(const ClearMetadataEvent());

    final tokens = AuraThemeTokens.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Añadido a la cola de descargas!',
          style: AuraTypography.bodyMedium.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final meta = state.previewMetadata;
        final hasMetadata = meta != null;
        if (meta != null && meta.url != _lastUrlForOptions) {
          _lastUrlForOptions = meta.url;
          _selectedVideoOption = null;
          _selectedAudioOption = null;
        }

        final activeVideoOpt = _activeVideoOption(meta);
        final activeAudioOpt = _activeAudioOption(meta);

        final actionLabel = () {
          if (!hasMetadata) return 'Añadir a la cola de descargas';
          if (_selectedMediaType == MediaType.audio) {
            if (activeAudioOpt != null) {
              return 'Añadir · ${activeAudioOpt.extension.toUpperCase()} ${activeAudioOpt.bitrateKbps} kbps';
            }
            return 'Añadir Audio (${_selectedAudioFormat.shortLabel})';
          }
          if (activeVideoOpt != null) {
            return 'Añadir · ${activeVideoOpt.resolutionTag} ${activeVideoOpt.container.toUpperCase()} (${activeVideoOpt.videoCodec})';
          }
          return 'Añadir a la cola de descargas';
        }();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraDimensions.space5,
            vertical: AuraDimensions.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Descargar contenido',
                style: AuraTypography.headingLarge
                    .copyWith(color: tokens.textPrimary),
              ),
              const SizedBox(height: AuraDimensions.space2),
              Text(
                'Pega un enlace de YouTube o comparte directamente desde la app para descargar audio o video.',
                style: AuraTypography.bodyMedium.copyWith(
                  color: tokens.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AuraDimensions.space6),

              Container(
                height: AuraDimensions.inputHeight,
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: AuraDimensions.radiusMedium,
                  border: Border.all(
                    color:
                        state.isLoadingMetadata ? tokens.primary : tokens.divider,
                    width: state.isLoadingMetadata ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraDimensions.space4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      color: state.isLoadingMetadata
                          ? tokens.primary
                          : tokens.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: AuraDimensions.space3),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: AuraTypography.bodyMedium.copyWith(
                          color: tokens.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://youtube.com/watch?v=...',
                          hintStyle: AuraTypography.bodyMedium.copyWith(
                            color: tokens.textSecondary,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _fetchMetadata(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_urlController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _urlController.clear();
                          _selectedVideoOption = null;
                          _selectedAudioOption = null;
                          context
                              .read<DownloadBloc>()
                              .add(const ClearMetadataEvent());
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(width: AuraDimensions.space1),
                    _PastePill(onTap: _pasteFromClipboard, tokens: tokens),
                  ],
                ),
              ),

              const SizedBox(height: AuraDimensions.space3),

              AuraButton(
                label: state.isLoadingMetadata
                    ? 'Analizando enlace...'
                    : 'Analizar enlace',
                icon: Icons.search_rounded,
                variant: AuraButtonVariant.secondary,
                isLoading: state.isLoadingMetadata,
                onPressed: state.isLoadingMetadata ? null : _fetchMetadata,
              ),

              if (state.metadataError != null) ...[
                const SizedBox(height: AuraDimensions.space4),
                Container(
                  padding: const EdgeInsets.all(AuraDimensions.space4),
                  decoration: BoxDecoration(
                    color: tokens.error.withValues(alpha: 0.1),
                    borderRadius: AuraDimensions.radiusMedium,
                    border: Border.all(
                      color: tokens.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: tokens.error,
                        size: AuraDimensions.smallIconSize,
                      ),
                      const SizedBox(width: AuraDimensions.space3),
                      Expanded(
                        child: Text(
                          state.metadataError!,
                          style: AuraTypography.bodySmall.copyWith(
                            color: tokens.error,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (meta != null) ...[
                const SizedBox(height: AuraDimensions.space5),
                MediaPreviewCard(
                  metadata: meta,
                  onClear: () {
                    _selectedVideoOption = null;
                    _selectedAudioOption = null;
                    context
                        .read<DownloadBloc>()
                        .add(const ClearMetadataEvent());
                  },
                ),
              ],

              const SizedBox(height: AuraDimensions.space5),

              AuraFormatSelector(
                selectedMediaType: _selectedMediaType,
                selectedQuality: _selectedQuality,
                audioSizeBytes: meta?.audioSizeBytes,
                videoSizeBytes: meta?.videoSizeBytes,
                audioExtensionLabel: _selectedAudioFormat.shortLabel,
                availableQualities: meta?.availableQualities ??
                    const [
                      VideoQuality.best,
                      VideoQuality.p1080,
                      VideoQuality.p720,
                      VideoQuality.p480,
                      VideoQuality.p360,
                    ],
                videoOptions: meta?.videoOptions ?? const [],
                selectedVideoOption: activeVideoOpt,
                onVideoOptionChanged: (opt) => setState(() {
                  _selectedVideoOption = opt;
                  _selectedQuality = opt.quality;
                }),
                audioOptions: meta?.audioOptions ?? const [],
                selectedAudioOption: activeAudioOpt,
                onAudioOptionChanged: (opt) => setState(() {
                  _selectedAudioOption = opt;
                  _selectedAudioFormat = opt.format;
                }),
                selectedAudioFormat: _selectedAudioFormat,
                onAudioFormatChanged: (fmt) => setState(() {
                  _selectedAudioFormat = fmt;
                  _selectedAudioOption = meta?.bestAudioOptionFor(fmt);
                }),
                isResolvingFormats:
                    meta != null && !meta.analysisStage.hasStreams,
                onMediaTypeChanged: (type) =>
                    setState(() => _selectedMediaType = type),
                onQualityChanged: (q) => setState(() {
                  _selectedQuality = q;
                  _selectedVideoOption = meta?.bestVideoOptionFor(
                    q,
                    _selectedVideoFormatPref,
                  );
                }),
              ),

              const SizedBox(height: AuraDimensions.space6),

              AuraButton(
                label: actionLabel,
                icon: Icons.download_rounded,
                variant: AuraButtonVariant.primary,
                onPressed: hasMetadata ? () => _addToQueue(state) : null,
              ),

              if (state.downloadingCount > 0 || state.queuedCount > 0) ...[
                const SizedBox(height: AuraDimensions.space5),
                AuraCard(
                  borderColor: tokens.primary.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraDimensions.space4,
                    vertical: 14,
                  ),
                  onTap: widget.onNavigateToQueue,
                  child: Row(
                    children: [
                      Icon(
                        Icons.downloading_rounded,
                        color: tokens.primary,
                        size: 22,
                      ),
                      const SizedBox(width: AuraDimensions.space3),
                      Expanded(
                        child: Text(
                          '${state.downloadingCount} descargando · ${state.queuedCount} en espera',
                          style: AuraTypography.metricSmall.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Ver cola',
                        style: AuraTypography.label.copyWith(
                          color: tokens.primary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: tokens.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PastePill extends StatelessWidget {
  final VoidCallback onTap;
  final AuraThemeTokens tokens;
  const _PastePill({required this.onTap, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.primary.withValues(alpha: 0.14),
      borderRadius: AuraDimensions.radiusSmall,
      child: InkWell(
        onTap: onTap,
        borderRadius: AuraDimensions.radiusSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraDimensions.space3,
            vertical: 6,
          ),
          child: Text(
            'Pegar',
            style: AuraTypography.label.copyWith(
              color: tokens.primary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
