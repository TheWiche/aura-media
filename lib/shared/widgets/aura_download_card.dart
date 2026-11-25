import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';
import '../../core/theme/aura_typography.dart';
import '../../core/utils/formatters.dart';
import '../../features/downloader/data/models/download_task.dart';
import 'aura_card.dart';
import 'aura_progress.dart';

class AuraDownloadCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  const AuraDownloadCard({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAudio = task.mediaType == MediaType.audio;
    final formatColor =
        isAudio ? AuraColors.audio(isDark) : AuraColors.video(isDark);
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);

    final progressColor = switch (task.status) {
      DownloadStatus.paused => AuraColors.warning(isDark),
      DownloadStatus.failed => AuraColors.error(isDark),
      DownloadStatus.completed => AuraColors.audio(isDark),
      _ => AuraColors.primary(isDark),
    };

    final extUpper = task.fileExtension.toUpperCase();
    final formatSubtitle = isAudio
        ? '$extUpper · Audio'
        : '$extUpper · ${_qualityShort(task.quality)}';

    final speedText = Formatters.formatSpeed(task.speedBytesPerSec);
    final remainingBytes =
        (task.totalBytes - task.downloadedBytes).clamp(0, task.totalBytes);
    final etaText = Formatters.formatETA(remainingBytes, task.speedBytesPerSec);

    return AuraCard(
      padding: const EdgeInsets.all(AuraDimensions.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
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
              // Title & format badge
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: formatColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            formatSubtitle,
                            style: AuraTypography.metricSmall.copyWith(
                              fontSize: 11,
                              color: formatColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AuraDimensions.space2),
                        _StatusPill(task: task),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AuraDimensions.space3),

          // Progress bar + monospace percentage
          Row(
            children: [
              Expanded(
                child: AuraProgress(
                  value: task.status == DownloadStatus.queued
                      ? null
                      : task.progress,
                  color: progressColor,
                  height: 6,
                ),
              ),
              const SizedBox(width: AuraDimensions.space3),
              Text(
                task.status == DownloadStatus.queued
                    ? '...'
                    : '${task.progressPercent}%',
                style: AuraTypography.metricMedium.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AuraDimensions.space3),

          // Metrics row (JetBrains Mono) + circular action buttons
          Row(
            children: [
              Expanded(
                child: _buildMetricsRow(
                  context: context,
                  isDark: isDark,
                  speedText: speedText,
                  etaText: etaText,
                  textSecondary: textSecondary,
                ),
              ),
              _buildActionButtons(context, isDark),
            ],
          ),

          if (task.errorMessage != null &&
              (task.status == DownloadStatus.failed ||
                  task.status == DownloadStatus.paused)) ...[
            const SizedBox(height: AuraDimensions.space3),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraDimensions.space3,
                vertical: AuraDimensions.space2,
              ),
              decoration: BoxDecoration(
                color: (task.status == DownloadStatus.paused
                        ? AuraColors.warning(isDark)
                        : AuraColors.error(isDark))
                    .withValues(alpha: 0.1),
                borderRadius: AuraDimensions.radiusSmall,
              ),
              child: Row(
                children: [
                  Icon(
                    task.status == DownloadStatus.paused
                        ? Icons.wifi_tethering_error_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: task.status == DownloadStatus.paused
                        ? AuraColors.warning(isDark)
                        : AuraColors.error(isDark),
                  ),
                  const SizedBox(width: AuraDimensions.space2),
                  Expanded(
                    child: Text(
                      task.errorMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraTypography.bodySmall.copyWith(
                        color: task.status == DownloadStatus.paused
                            ? AuraColors.warning(isDark)
                            : AuraColors.error(isDark),
                      ),
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

  Widget _buildMetricsRow({
    required BuildContext context,
    required bool isDark,
    required String speedText,
    required String etaText,
    required Color textSecondary,
  }) {
    if (task.status == DownloadStatus.queued) {
      return Text(
        'En espera de turno...',
        style: AuraTypography.bodySmall.copyWith(color: textSecondary),
      );
    }
    if (task.status == DownloadStatus.paused) {
      return Text(
        '${Formatters.formatBytes(task.downloadedBytes)} · Pausado',
        style: AuraTypography.metricSmall.copyWith(color: textSecondary),
      );
    }
    if (task.status == DownloadStatus.failed) {
      return Text(
        'Descarga interrumpida',
        style: AuraTypography.bodySmall.copyWith(
          color: AuraColors.error(isDark),
        ),
      );
    }

    return Wrap(
      spacing: AuraDimensions.space3,
      runSpacing: AuraDimensions.space1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 14,
              color: AuraColors.primary(isDark),
            ),
            const SizedBox(width: 3),
            Text(
              speedText,
              style: AuraTypography.metricSmall.copyWith(color: textSecondary),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 13,
              color: textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              etaText,
              style: AuraTypography.metricSmall.copyWith(color: textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    if (task.status == DownloadStatus.downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleIconButton(
            icon: Icons.pause_rounded,
            tooltip: 'Pausar',
            color: AuraColors.warning(isDark),
            onPressed: onPause,
          ),
          const SizedBox(width: AuraDimensions.space2),
          _CircleIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Cancelar',
            color: AuraColors.error(isDark),
            onPressed: onCancel,
          ),
        ],
      );
    }

    if (task.status == DownloadStatus.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleIconButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Reanudar',
            color: AuraColors.primary(isDark),
            onPressed: onResume,
          ),
          const SizedBox(width: AuraDimensions.space2),
          _CircleIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: AuraColors.textSecondary(isDark),
            onPressed: onRemove,
          ),
        ],
      );
    }

    if (task.status == DownloadStatus.queued) {
      return _CircleIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Quitar de la cola',
        color: AuraColors.textSecondary(isDark),
        onPressed: onCancel,
      );
    }

    if (task.status == DownloadStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Reintentar',
            color: AuraColors.primary(isDark),
            onPressed: onRetry,
          ),
          const SizedBox(width: AuraDimensions.space2),
          _CircleIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: AuraColors.textSecondary(isDark),
            onPressed: onRemove,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  static String _qualityShort(VideoQuality q) {
    return switch (q) {
      VideoQuality.best => 'Mejor',
      VideoQuality.p1080 => '1080p',
      VideoQuality.p720 => '720p',
      VideoQuality.p480 => '480p',
      VideoQuality.p360 => '360p',
    };
  }
}

class _StatusPill extends StatelessWidget {
  final DownloadTask task;
  const _StatusPill({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, color) = switch (task.status) {
      DownloadStatus.queued => ('En cola', AuraColors.video(isDark)),
      DownloadStatus.downloading => ('Descargando', AuraColors.primary(isDark)),
      DownloadStatus.paused => ('Pausado', AuraColors.warning(isDark)),
      DownloadStatus.completed => ('Listo', AuraColors.audio(isDark)),
      DownloadStatus.failed => ('Error', AuraColors.error(isDark)),
      DownloadStatus.canceled => ('Cancelado', AuraColors.textSecondary(isDark)),
    };

    return Text(
      '· $label',
      style: AuraTypography.bodySmall.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? AuraColors.darkSurface : AuraColors.lightBackground,
        shape: CircleBorder(
          side: BorderSide(color: AuraColors.divider(isDark), width: 1),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
