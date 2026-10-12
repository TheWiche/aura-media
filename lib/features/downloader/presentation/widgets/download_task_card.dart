import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/download_task.dart';

class DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  const DownloadTaskCard({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header: Icon/Thumbnail + Title + Status Badge
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
                          errorBuilder: (ctx, err, stack) => _buildTypeIcon(),
                        )
                      : _buildTypeIcon(),
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
                    const SizedBox(height: 2),
                    Text(
                      '${task.mediaType == MediaType.audio ? "Audio (${task.fileExtension.toUpperCase()})" : "Video (${task.quality.label})"} • ${task.author ?? "Media"}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: task.status == DownloadStatus.queued
                  ? null // indeterminate when queued waiting
                  : task.progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
            ),
          ),

          const SizedBox(height: 10),

          // Details: Speed, Progress % & ETA
          Row(
            children: [
              // Percent & Bytes
              Expanded(
                child: Text(
                  _getProgressMetricsText(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),

              // Action buttons
              _buildActionButtons(),
            ],
          ),

          // Error message banner if failed
          if (task.errorMessage != null && task.status == DownloadStatus.failed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.errorMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.error, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeIcon() {
    return Icon(
      task.mediaType == MediaType.audio ? Icons.music_note : Icons.movie,
      color: AppColors.primary,
      size: 22,
    );
  }

  Widget _buildStatusBadge() {
    final (label, color) = switch (task.status) {
      DownloadStatus.queued => ('En cola', AppColors.statusQueued),
      DownloadStatus.downloading => ('Descargando', AppColors.statusDownloading),
      DownloadStatus.paused => ('Pausado', AppColors.statusPaused),
      DownloadStatus.completed => ('Listo', AppColors.statusCompleted),
      DownloadStatus.failed => ('Error', AppColors.statusFailed),
      DownloadStatus.canceled => ('Cancelado', AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    return switch (task.status) {
      DownloadStatus.downloading => AppColors.primary,
      DownloadStatus.paused => AppColors.warning,
      DownloadStatus.failed => AppColors.error,
      DownloadStatus.completed => AppColors.accent,
      _ => AppColors.primary,
    };
  }

  String _getProgressMetricsText() {
    if (task.status == DownloadStatus.queued) {
      return 'Esperando turno...';
    }
    if (task.status == DownloadStatus.paused) {
      return '${task.progressPercent}% • Pausado';
    }
    if (task.status == DownloadStatus.failed) {
      return 'Descarga interrumpida';
    }

    final downloadedStr = Formatters.formatBytes(task.downloadedBytes);
    final totalStr = task.totalBytes > 0 ? Formatters.formatBytes(task.totalBytes) : '...';
    final speedStr = Formatters.formatSpeed(task.speedBytesPerSec);
    final etaStr = Formatters.formatETA(task.totalBytes - task.downloadedBytes, task.speedBytesPerSec);

    return '${task.progressPercent}% • $downloadedStr de $totalStr • $speedStr • ETA $etaStr';
  }

  Widget _buildActionButtons() {
    if (task.status == DownloadStatus.downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.pause_circle_outline, color: AppColors.warning, size: 22),
            onPressed: onPause,
            tooltip: 'Pausar',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
            onPressed: onCancel,
            tooltip: 'Cancelar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    if (task.status == DownloadStatus.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline, color: AppColors.accent, size: 22),
            onPressed: onResume,
            tooltip: 'Reanudar',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 22),
            onPressed: onRemove,
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    if (task.status == DownloadStatus.queued) {
      return IconButton(
        icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
        onPressed: onCancel,
        tooltip: 'Quitar de la cola',
        visualDensity: VisualDensity.compact,
      );
    }

    if (task.status == DownloadStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary, size: 22),
            onPressed: onRetry,
            tooltip: 'Reintentar',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 22),
            onPressed: onRemove,
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

