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
    final tokens = AuraThemeTokens.of(context);
    final effectiveQuality = availableQualities.contains(selectedQuality)
        ? selectedQuality
        : availableQualities.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORMATO DE DESCARGA',
          style: AuraTypography.bodySmall.copyWith(
            color: tokens.textSecondary,
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
                semanticColor: tokens.audio,
                selectedColor: tokens.primary,
                checkIconColor: tokens.onPrimary,
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
                semanticColor: tokens.video,
                selectedColor: tokens.primary,
                checkIconColor: tokens.onPrimary,
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
            style: AuraTypography.label.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: AuraDimensions.space2),
          Wrap(
            spacing: AuraDimensions.space2,
            runSpacing: AuraDimensions.space2,
            children: availableQualities.map((quality) {
              final selected = quality == effectiveQuality;
              return Material(
                color: selected
                    ? tokens.primary.withValues(alpha: tokens.isDark ? 0.2 : 0.14)
                    : tokens.card,
                shape: RoundedRectangleBorder(
                  borderRadius: AuraDimensions.radiusSmall,
                  side: BorderSide(
                    color: selected ? tokens.primary : tokens.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onQualityChanged(quality),
                  borderRadius: AuraDimensions.radiusSmall,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraDimensions.space3,
                      vertical: AuraDimensions.space2,
                    ),
                    child: Text(
                      _shortQuality(quality),
                      style: AuraTypography.metricSmall.copyWith(
                        color: selected ? tokens.primary : tokens.textPrimary,
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
  final Color semanticColor;
  final Color selectedColor;
  final Color checkIconColor;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _FormatTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.semanticColor,
    required this.selectedColor,
    required this.checkIconColor,
    required this.isSelected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);
    final bg = isSelected
        ? selectedColor.withValues(alpha: tokens.isDark ? 0.12 : 0.08)
        : tokens.card;
    final border = isSelected ? selectedColor : tokens.divider;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: AuraDimensions.radiusMedium,
        side: BorderSide(color: border, width: isSelected ? 1.8 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AuraDimensions.radiusMedium,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AuraDimensions.space3,
            vertical: compact ? AuraDimensions.space3 : 14,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 2),
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: semanticColor.withValues(alpha: 0.16),
                        borderRadius: AuraDimensions.radiusSmall,
                      ),
                      child: Icon(icon, color: semanticColor, size: 22),
                    ),
                    const SizedBox(height: AuraDimensions.space2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AuraTypography.label.copyWith(
                        color:
                            isSelected ? tokens.textPrimary : tokens.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AuraTypography.metricSmall.copyWith(
                        color:
                            isSelected ? semanticColor : tokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: checkIconColor,
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
