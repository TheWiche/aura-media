import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/aura_card.dart';
import '../../data/models/download_task.dart';

class CompletedTaskCard extends StatelessWidget {
  final DownloadTask task;
  final void Function(bool deletePhysicalFile) onRemove;

  const CompletedTaskCard({
    super.key,
    required this.task,
    required this.onRemove,
  });

  Future<void> _openFile(BuildContext context) async {
    if (task.savedPath == null) return;
    try {
      final result = await OpenFilex.open(task.savedPath!);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el archivo: ${result.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir: $e')),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    if (task.savedPath == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(task.savedPath!)],
        title: task.title,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    bool deleteFromDisk = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errColor = AuraColors.error(isDark);
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Eliminar elemento',
                style: AuraTypography.headingSmall.copyWith(color: textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Deseas eliminar "${task.title}" del historial?',
                    style: AuraTypography.bodyMedium.copyWith(
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: AuraDimensions.space4),
                  InkWell(
                    onTap: () =>
                        setState(() => deleteFromDisk = !deleteFromDisk),
                    borderRadius: AuraDimensions.radiusSmall,
                    child: Row(
                      children: [
                        Checkbox(
                          value: deleteFromDisk,
                          activeColor: errColor,
                          onChanged: (val) =>
                              setState(() => deleteFromDisk = val ?? true),
                        ),
                        Expanded(
                          child: Text(
                            'Borrar archivo físico del disco',
                            style: AuraTypography.bodyMedium
                                .copyWith(color: textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: AuraTypography.label.copyWith(color: textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errColor,
                    foregroundColor: AuraColors.white,
                    minimumSize: const Size(110, 42),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AuraDimensions.radiusSmall,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onRemove(deleteFromDisk);
                  },
                  child: Text(
                    'Eliminar',
                    style: AuraTypography.label.copyWith(color: AuraColors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAudio = task.mediaType == MediaType.audio;
    final formatColor =
        isAudio ? AuraColors.audio(isDark) : AuraColors.video(isDark);
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final divider = AuraColors.divider(isDark);
    final primary = AuraColors.primary(isDark);
    final errColor = AuraColors.error(isDark);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = task.completedAt != null
        ? dateFormat.format(task.completedAt!)
        : 'Reciente';

    return AuraCard(
      padding: const EdgeInsets.all(AuraDimensions.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AuraDimensions.radiusSmall,
                child: Container(
                  width: 56,
                  height: 56,
                  color: formatColor.withValues(alpha: 0.14),
                  child: task.thumbnailUrl != null
                      ? Image.network(
                          task.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            isAudio
                                ? Icons.music_note_rounded
                                : Icons.videocam_rounded,
                            color: formatColor,
                            size: 24,
                          ),
                        )
                      : Icon(
                          isAudio
                              ? Icons.music_note_rounded
                              : Icons.videocam_rounded,
                          color: formatColor,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: AuraDimensions.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraTypography.label.copyWith(
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: AuraDimensions.space1),
                    Wrap(
                      spacing: AuraDimensions.space2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: formatColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.fileExtension.toUpperCase(),
                            style: AuraTypography.metricSmall.copyWith(
                              fontSize: 11,
                              color: formatColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${Formatters.formatBytes(task.downloadedBytes)} · $formattedDate',
                          style: AuraTypography.metricSmall.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraDimensions.space3),
          Divider(height: 1, color: divider),
          const SizedBox(height: AuraDimensions.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: formatColor,
                  ),
                  label: Text(
                    'Reproducir',
                    style: AuraTypography.label.copyWith(color: textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: BorderSide(color: divider),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AuraDimensions.radiusMedium,
                    ),
                  ),
                  onPressed: () => _openFile(context),
                ),
              ),
              const SizedBox(width: AuraDimensions.space2),
              IconButton(
                icon: Icon(Icons.share_rounded, color: primary, size: 20),
                onPressed: _shareFile,
                tooltip: 'Compartir',
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: primary.withValues(alpha: 0.12),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AuraDimensions.radiusMedium,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: errColor,
                  size: 20,
                ),
                onPressed: () => _showDeleteDialog(context),
                tooltip: 'Eliminar',
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: errColor.withValues(alpha: 0.12),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AuraDimensions.radiusMedium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
