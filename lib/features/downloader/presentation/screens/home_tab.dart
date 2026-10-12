import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/download_task.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import '../widgets/format_selector_chip.dart';
import '../widgets/media_preview_card.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToQueue;

  const HomeTab({
    super.key,
    required this.onNavigateToQueue,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _urlController = TextEditingController();
  MediaType _selectedMediaType = MediaType.video;
  VideoQuality _selectedQuality = VideoQuality.best;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      _fetchMetadata();
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
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa o pega un enlace válido.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    context.read<DownloadBloc>().add(
          EnqueueDownloadEvent(
            url: url,
            mediaType: _selectedMediaType,
            quality: _selectedQuality,
            metadata: state.previewMetadata,
          ),
        );

    _urlController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enlace añadido a la cola de descargas.'),
        backgroundColor: AppColors.accent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner / Title
              const Text(
                'Descargar Contenido',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pega enlaces de YouTube o plataformas compatibles para extraer video y audio de alta fidelidad.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Input Field with Paste & Search Buttons
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'https://youtube.com/watch?v=...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _fetchMetadata(),
                      ),
                    ),
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          _urlController.clear();
                          context.read<DownloadBloc>().add(const ClearMetadataEvent());
                          setState(() {});
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      icon: const Icon(Icons.paste_rounded, size: 20, color: AppColors.secondary),
                      tooltip: 'Pegar del portapapeles',
                      onPressed: _pasteFromClipboard,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Action button to analyze link
              OutlinedButton.icon(
                onPressed: state.isLoadingMetadata ? null : _fetchMetadata,
                icon: state.isLoadingMetadata
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.search, size: 18),
                label: Text(
                  state.isLoadingMetadata ? 'Obteniendo detalles...' : 'Analizar Enlace',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              // Error display
              if (state.metadataError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.metadataError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Metadata Preview
              if (state.previewMetadata != null) ...[
                const SizedBox(height: 16),
                MediaPreviewCard(
                  metadata: state.previewMetadata!,
                  onClear: () {
                    context.read<DownloadBloc>().add(const ClearMetadataEvent());
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Format and Quality Selector
              FormatSelectorChip(
                selectedMediaType: _selectedMediaType,
                selectedQuality: _selectedQuality,
                availableQualities: state.previewMetadata?.availableQualities ?? const [
                  VideoQuality.best,
                  VideoQuality.p1080,
                  VideoQuality.p720,
                  VideoQuality.p480,
                  VideoQuality.p360,
                ],
                onMediaTypeChanged: (type) => setState(() => _selectedMediaType = type),
                onQualityChanged: (q) => setState(() => _selectedQuality = q),
              ),

              const SizedBox(height: 24),

              // Prominent "Añadir a la cola" Button
              ElevatedButton.icon(
                onPressed: () => _addToQueue(state),
                icon: const Icon(Icons.add_to_photos_rounded, size: 20),
                label: const Text(
                  'Añadir a la cola de descargas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              // Active downloads banner if running
              if (state.downloadingCount > 0 || state.queuedCount > 0) ...[
                const SizedBox(height: 20),
                InkWell(
                  onTap: widget.onNavigateToQueue,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.downloading, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${state.downloadingCount} descargando • ${state.queuedCount} en espera',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Text(
                          'Ver cola',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                      ],
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

