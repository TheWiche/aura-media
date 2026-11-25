import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';
import '../../core/theme/aura_typography.dart';
import '../../core/utils/formatters.dart';
import '../../features/downloader/data/models/download_task.dart';

class AuraFormatSelector extends StatelessWidget {
  final MediaType selectedMediaType;
  final VideoQuality selectedQuality;
  final ValueChanged<MediaType> onMediaTypeChanged;
  final ValueChanged<VideoQuality> onQualityChanged;
  final List<VideoQuality> availableQualities;
  final int? audioSizeBytes;
  final int? videoSizeBytes;
  final String audioExtensionLabel;
  final bool compact;

  const AuraFormatSelector({
    super.key,
    required this.selectedMediaType,
    required this.selectedQuality,
    required this.onMediaTypeChanged,
    required this.onQualityChanged,
    this.availableQualities = const [
      VideoQuality.best,
      VideoQuality.p1080,
      VideoQuality.p720,
      VideoQuality.p480,
      VideoQuality.p360,
    ],
    this.audioSizeBytes,
    this.videoSizeBytes,
    this.audioExtensionLabel = 'MP3',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = AuraColors.textSecondary(isDark);
    final audioColor = AuraColors.audio(isDark);
    final videoColor = AuraColors.video(isDark);
    final primaryColor = AuraColors.primary(isDark);

    final effectiveQuality = availableQualities.contains(selectedQuality)
        ? selectedQuality
        : availableQualities.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORMATO DE DESCARGA',
          style: AuraTypography.bodySmall.copyWith(
            color: textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: AuraDimensions.space2),
        Row(
          children: [
            Expanded(
              child: _FormatTile(
                title: 'Solo Audio',
                subtitle: audioSizeBytes != null
                    ? '$audioExtensionLabel · ${Formatters.formatBytes(audioSizeBytes!)}'
                    : '$audioExtensionLabel · Alta calidad',
                icon: Icons.music_note_rounded,
                accentColor: audioColor,
                selectedBorderColor: primaryColor,
                isSelected: selectedMediaType == MediaType.audio,
                compact: compact,
                onTap: () => onMediaTypeChanged(MediaType.audio),
              ),
            ),
            const SizedBox(width: AuraDimensions.space3),
            Expanded(
              child: _FormatTile(
                title: 'Video',
                subtitle: videoSizeBytes != null
                    ? 'MP4 · ${Formatters.formatBytes(videoSizeBytes!)}'
                    : 'MP4 · ${_shortQuality(effectiveQuality)}',
                icon: Icons.videocam_rounded,
                accentColor: videoColor,
                selectedBorderColor: videoColor,
                isSelected: selectedMediaType == MediaType.video,
                compact: compact,
                onTap: () => onMediaTypeChanged(MediaType.video),
              ),
            ),
          ],
        ),

        // Quality chips when Video is selected
        if (selectedMediaType == MediaType.video) ...[
          const SizedBox(height: AuraDimensions.space3),
          Text(
            'Resolución de video',
            style: AuraTypography.label.copyWith(color: textSecondary),
          ),
          const SizedBox(height: AuraDimensions.space2),
          Wrap(
            spacing: AuraDimensions.space2,
            runSpacing: AuraDimensions.space2,
            children: availableQualities.map((quality) {
              final selected = quality == effectiveQuality;
              return Material(
                color: Colors.transparent,
                borderRadius: AuraDimensions.radiusSmall,
                child: InkWell(
                  onTap: () => onQualityChanged(quality),
                  borderRadius: AuraDimensions.radiusSmall,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space3,
                      vertical: AuraDimensions.space2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? videoColor.withValues(alpha: isDark ? 0.2 : 0.14)
                          : AuraColors.card(isDark),
                      borderRadius: AuraDimensions.radiusSmall,
                      border: Border.all(
                        color: selected
                            ? videoColor
                            : AuraColors.divider(isDark),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      _shortQuality(quality),
                      style: AuraTypography.metricSmall.copyWith(
                        color: selected
                            ? videoColor
                            : AuraColors.textPrimary(isDark),
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  static String _shortQuality(VideoQuality quality) {
    return switch (quality) {
      VideoQuality.best => 'Mejor',
      VideoQuality.p1080 => '1080p',
      VideoQuality.p720 => '720p',
      VideoQuality.p480 => '480p',
      VideoQuality.p360 => '360p',
    };
  }
}

class _FormatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color selectedBorderColor;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _FormatTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.selectedBorderColor,
    required this.isSelected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AuraColors.card(isDark);
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final divider = AuraColors.divider(isDark);

    return Material(
      color: Colors.transparent,
      borderRadius: AuraDimensions.radiusMedium,
      child: InkWell(
        onTap: onTap,
        borderRadius: AuraDimensions.radiusMedium,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: AuraDimensions.space3,
            vertical: compact ? AuraDimensions.space3 : 14,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedBorderColor.withValues(alpha: isDark ? 0.12 : 0.08)
                : cardBg,
            borderRadius: AuraDimensions.radiusMedium,
            border: Border.all(
              color: isSelected ? selectedBorderColor : divider,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: AuraDimensions.radiusSmall,
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(height: AuraDimensions.space2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.label.copyWith(
                      color: isSelected ? textPrimary : textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraTypography.metricSmall.copyWith(
                      color: isSelected ? accentColor : textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: selectedBorderColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: isDark
                          ? const Color(0xFF171D15)
                          : AuraColors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
