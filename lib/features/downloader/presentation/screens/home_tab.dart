import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/settings_service.dart';
import '../../data/datasources/youtube_extractor.dart';
import '../../data/models/download_task.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import '../widgets/format_selector_chip.dart';
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
  MediaType _selectedMediaType = MediaType.video;
  late VideoQuality _selectedQuality;

  @override
  void initState() {
    super.initState();
    _selectedQuality = SettingsService.instance.getDefaultQuality();

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleIncomingUrl(widget.initialUrl!);
      });
    }
  }

  @override
  void dispose() {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Añadido a la cola de descargas!',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final hasMetadata = state.previewMetadata != null;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero header ────────────────────────────────────────────────
              Text(
                'Descargar contenido',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pega un enlace de YouTube o comparte directamente desde la app para extraer video o audio.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // ── URL Input — fluid, borderless pill ─────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: state.isLoadingMetadata
                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5)
                      : Border.all(color: Colors.transparent),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      color: state.isLoadingMetadata ? AppColors.primary : AppColors.primary.withValues(alpha: 0.7),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://youtube.com/watch?v=...',
                          hintStyle: GoogleFonts.outfit(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _fetchMetadata(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    // Clear button
                    if (_urlController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _urlController.clear();
                          context.read<DownloadBloc>().add(const ClearMetadataEvent());
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    // Paste button
                    const SizedBox(width: 4),
                    _PasteButton(onTap: _pasteFromClipboard),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Analyze button with interactive scale ──────────────────────
              _ScaleBounceButton(
                onPressed: state.isLoadingMetadata ? null : _fetchMetadata,
                child: OutlinedButton.icon(
                  onPressed: state.isLoadingMetadata ? null : _fetchMetadata,
                  icon: state.isLoadingMetadata
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.search_rounded, size: 18),
                  label: Text(
                    state.isLoadingMetadata ? 'Analizando enlace...' : 'Analizar enlace',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
              ),

              // ── Error display ──────────────────────────────────────────────
              if (state.metadataError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.metadataError!,
                          style: GoogleFonts.outfit(
                            color: AppColors.error,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Metadata Preview card ──────────────────────────────────────
              if (state.previewMetadata != null) ...[
                const SizedBox(height: 18),
                MediaPreviewCard(
                  metadata: state.previewMetadata!,
                  onClear: () {
                    context.read<DownloadBloc>().add(const ClearMetadataEvent());
                  },
                ),
              ],

              const SizedBox(height: 22),

              // ── Format & Quality Selector ──────────────────────────────────
              FormatSelectorChip(
                selectedMediaType: _selectedMediaType,
                selectedQuality: _selectedQuality,
                availableQualities: state.previewMetadata?.availableQualities ??
                    const [
                      VideoQuality.best,
                      VideoQuality.p1080,
                      VideoQuality.p720,
                      VideoQuality.p480,
                      VideoQuality.p360,
                    ],
                onMediaTypeChanged: (type) => setState(() => _selectedMediaType = type),
                onQualityChanged: (q) => setState(() => _selectedQuality = q),
              ),

              const SizedBox(height: 26),

              // ── "Añadir a la cola" — DISABLED until metadata is fetched ────
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: hasMetadata ? 1.0 : 0.4,
                child: _ScaleBounceButton(
                  onPressed: hasMetadata ? () => _addToQueue(state) : null,
                  child: ElevatedButton.icon(
                    // onPressed: null disables the button truly
                    onPressed: hasMetadata ? () => _addToQueue(state) : null,
                    icon: const Icon(Icons.add_to_photos_rounded, size: 20),
                    label: const Text('Añadir a la cola de descargas'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      disabledBackgroundColor: AppColors.primary,
                      disabledForegroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

              // ── Active downloads banner ────────────────────────────────────
              if (state.downloadingCount > 0 || state.queuedCount > 0) ...[
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: widget.onNavigateToQueue,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.downloading_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${state.downloadingCount} descargando · ${state.queuedCount} en espera',
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'Ver cola',
                            style: GoogleFonts.outfit(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
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

// ─── Interactive scale bounce wrapper ────────────────────────────────────────
class _ScaleBounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const _ScaleBounceButton({required this.child, required this.onPressed});

  @override
  State<_ScaleBounceButton> createState() => _ScaleBounceButtonState();
}

class _ScaleBounceButtonState extends State<_ScaleBounceButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onPressed == null) return widget.child;

    return Listener(
      onPointerDown: (_) => setState(() => _isDown = true),
      onPointerUp: (_) => setState(() => _isDown = false),
      onPointerCancel: (_) => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

// ─── Paste button pill ───────────────────────────────────────────────────────
class _PasteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PasteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            'Pegar',
            style: GoogleFonts.outfit(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
