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
  late String _audioExtensionLabel;

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
    _selectedMediaType = SettingsService.instance.getDefaultMediaType();
    _selectedQuality = SettingsService.instance.getDefaultQuality();
    _audioExtensionLabel =
        SettingsService.instance.getAudioFormat().name.toUpperCase();
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
      setState(() {});
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
      context.read<DownloadBloc>().add(FetchMetadataEvent(text));
    }
  }

  void _addToQueue(DownloadState state) {
    final url = _urlController.text.trim();
    if (url.isEmpty || state.previewMetadata == null) return;

    context.read<DownloadBloc>().add(
          EnqueueDownloadEvent(
            url: url,
            mediaType: _selectedMediaType,
            quality: _selectedQuality,
            metadata: state.previewMetadata,
          ),
        );

    _urlController.clear();
    context.read<DownloadBloc>().add(const ClearMetadataEvent());

    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Añadido a la cola de descargas!',
          style: AuraTypography.bodyMedium.copyWith(
            color: AuraColors.textPrimary(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final primary = AuraColors.primary(isDark);
    final divider = AuraColors.divider(isDark);

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final hasMetadata = state.previewMetadata != null;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraDimensions.space5,
            vertical: AuraDimensions.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero header ────────────────────────────────────────────────
              Text(
                'Descargar contenido',
                style: AuraTypography.headingLarge.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AuraDimensions.space2),
              Text(
                'Pega un enlace de YouTube o comparte directamente desde la app para descargar audio o video.',
                style: AuraTypography.bodyMedium.copyWith(
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AuraDimensions.space6),

              // ── URL Input (54dp height, 14dp radius) ──────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: AuraDimensions.inputHeight,
                decoration: BoxDecoration(
                  color: AuraColors.card(isDark),
                  borderRadius: AuraDimensions.radiusMedium,
                  border: Border.all(
                    color: state.isLoadingMetadata ? primary : divider,
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
                      color: state.isLoadingMetadata ? primary : textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: AuraDimensions.space3),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: AuraTypography.bodyMedium.copyWith(
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://youtube.com/watch?v=...',
                          hintStyle: AuraTypography.bodyMedium.copyWith(
                            color: textSecondary,
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
                            color: textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(width: AuraDimensions.space1),
                    _PastePill(onTap: _pasteFromClipboard),
                  ],
                ),
              ),

              const SizedBox(height: AuraDimensions.space3),

              // ── Secondary analyze button (NOT lime, per rule 7A) ──────────
              AuraButton(
                label: state.isLoadingMetadata
                    ? 'Analizando enlace...'
                    : 'Analizar enlace',
                icon: Icons.search_rounded,
                variant: AuraButtonVariant.secondary,
                isLoading: state.isLoadingMetadata,
                onPressed: state.isLoadingMetadata ? null : _fetchMetadata,
              ),

              // ── Error banner ───────────────────────────────────────────────
              if (state.metadataError != null) ...[
                const SizedBox(height: AuraDimensions.space4),
                Container(
                  padding: const EdgeInsets.all(AuraDimensions.space4),
                  decoration: BoxDecoration(
                    color: AuraColors.error(isDark).withValues(alpha: 0.1),
                    borderRadius: AuraDimensions.radiusMedium,
                    border: Border.all(
                      color: AuraColors.error(isDark).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: AuraColors.error(isDark),
                        size: AuraDimensions.smallIconSize,
                      ),
                      const SizedBox(width: AuraDimensions.space3),
                      Expanded(
                        child: Text(
                          state.metadataError!,
                          style: AuraTypography.bodySmall.copyWith(
                            color: AuraColors.error(isDark),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Preview card ───────────────────────────────────────────────
              if (state.previewMetadata != null) ...[
                const SizedBox(height: AuraDimensions.space5),
                MediaPreviewCard(
                  metadata: state.previewMetadata!,
                  onClear: () {
                    context
                        .read<DownloadBloc>()
                        .add(const ClearMetadataEvent());
                  },
                ),
              ],

              const SizedBox(height: AuraDimensions.space5),

              // ── Format & quality selector (Audio green / Video violet) ────
              AuraFormatSelector(
                selectedMediaType: _selectedMediaType,
                selectedQuality: _selectedQuality,
                audioSizeBytes: state.previewMetadata?.audioSizeBytes,
                videoSizeBytes: state.previewMetadata?.videoSizeBytes,
                audioExtensionLabel: _audioExtensionLabel,
                availableQualities:
                    state.previewMetadata?.availableQualities ??
                        const [
                          VideoQuality.best,
                          VideoQuality.p1080,
                          VideoQuality.p720,
                          VideoQuality.p480,
                          VideoQuality.p360,
                        ],
                onMediaTypeChanged: (type) =>
                    setState(() => _selectedMediaType = type),
                onQualityChanged: (q) => setState(() => _selectedQuality = q),
              ),

              const SizedBox(height: AuraDimensions.space6),

              // ── Primary Lime CTA ──────────────────────────────────────────
              AuraButton(
                label: 'Añadir a la cola de descargas',
                icon: Icons.download_rounded,
                variant: AuraButtonVariant.primary,
                onPressed: hasMetadata ? () => _addToQueue(state) : null,
              ),

              // ── Active downloads summary banner ───────────────────────────
              if (state.downloadingCount > 0 || state.queuedCount > 0) ...[
                const SizedBox(height: AuraDimensions.space5),
                AuraCard(
                  borderColor: primary.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraDimensions.space4,
                    vertical: 14,
                  ),
                  onTap: widget.onNavigateToQueue,
                  child: Row(
                    children: [
                      Icon(
                        Icons.downloading_rounded,
                        color: primary,
                        size: 22,
                      ),
                      const SizedBox(width: AuraDimensions.space3),
                      Expanded(
                        child: Text(
                          '${state.downloadingCount} descargando · ${state.queuedCount} en espera',
                          style: AuraTypography.metricSmall.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Ver cola',
                        style: AuraTypography.label.copyWith(
                          color: primary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: primary,
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
  const _PastePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AuraColors.primary(isDark);

    return Material(
      color: primary.withValues(alpha: 0.14),
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
              color: primary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
