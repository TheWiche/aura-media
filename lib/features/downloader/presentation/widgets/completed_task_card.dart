import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
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
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              title: const Text(
                'Eliminar elemento',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Deseas eliminar "${task.title}" del historial?',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setState(() => deleteFromDisk = !deleteFromDisk),
                    child: Row(
                      children: [
                        Checkbox(
                          value: deleteFromDisk,
                          activeColor: AppColors.error,
                          onChanged: (val) => setState(() => deleteFromDisk = val ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Borrar archivo físico del disco',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
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
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onRemove(deleteFromDisk);
                  },
                  child: const Text('Eliminar'),
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
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = task.completedAt != null
        ? dateFormat.format(task.completedAt!)
        : 'Reciente';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.surfaceVariant,
                  child: task.thumbnailUrl != null
                      ? Image.network(
                          task.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Icon(
                            task.mediaType == MediaType.audio ? Icons.music_note : Icons.movie,
                            color: AppColors.accent,
                            size: 24,
                          ),
                        )
                      : Icon(
                          task.mediaType == MediaType.audio ? Icons.music_note : Icons.movie,
                          color: AppColors.accent,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Formatters.formatBytes(task.downloadedBytes)} • ${task.fileExtension.toUpperCase()} • $formattedDate',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Action Buttons: Play, Share, Delete
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 18, color: AppColors.accent),
                  label: const Text('Reproducir', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: () => _openFile(context),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary, size: 20),
                onPressed: _shareFile,
                tooltip: 'Compartir',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _showDeleteDialog(context),
                tooltip: 'Eliminar',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

