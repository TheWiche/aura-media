import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              title: Text(
                'Eliminar elemento',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Deseas eliminar "${task.title}" del historial?',
                    style: GoogleFonts.outfit(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setState(() => deleteFromDisk = !deleteFromDisk),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: deleteFromDisk,
                          activeColor: AppColors.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) => setState(() => deleteFromDisk = val ?? true),
                        ),
                        Expanded(
                          child: Text(
                            'Borrar archivo físico del disco',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
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
                    style: GoogleFonts.outfit(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onRemove(deleteFromDisk);
                  },
                  child: Text('Eliminar', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = task.completedAt != null
        ? dateFormat.format(task.completedAt!)
        : 'Reciente';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 50,
                  height: 50,
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  child: task.thumbnailUrl != null
                      ? Image.network(
                          task.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Icon(
                            task.mediaType == MediaType.audio
                                ? Icons.music_note_rounded
                                : Icons.movie_rounded,
                            color: AppColors.accent,
                            size: 24,
                          ),
                        )
                      : Icon(
                          task.mediaType == MediaType.audio
                              ? Icons.music_note_rounded
                              : Icons.movie_rounded,
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
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.formatBytes(task.downloadedBytes)} · ${task.fileExtension.toUpperCase()} · $formattedDate',
                      style: GoogleFonts.outfit(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          const SizedBox(height: 10),
          // Action Buttons: Play, Share, Delete
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.accent),
                  label: Text(
                    'Reproducir',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _openFile(context),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: AppColors.primary, size: 20),
                onPressed: _shareFile,
                tooltip: 'Compartir',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                onPressed: () => _showDeleteDialog(context),
                tooltip: 'Eliminar',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
