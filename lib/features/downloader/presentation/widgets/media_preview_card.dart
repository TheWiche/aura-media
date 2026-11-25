import 'package:flutter/material.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/aura_card.dart';
import '../../data/models/media_metadata.dart';

class MediaPreviewCard extends StatelessWidget {
  final MediaMetadata metadata;
  final VoidCallback onClear;

  const MediaPreviewCard({
    super.key,
    required this.metadata,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AuraColors.primary(isDark);
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);

    return AuraCard(
      padding: const EdgeInsets.all(AuraDimensions.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AuraDimensions.radiusMedium,
            child: Container(
              width: 88,
              height: 88,
              color: primary.withValues(alpha: 0.12),
              child: metadata.thumbnailUrl != null
                  ? Image.network(
                      metadata.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.movie_creation_outlined,
                        color: textSecondary,
                      ),
                    )
                  : Icon(
                      Icons.video_library_outlined,
                      color: textSecondary,
                    ),
            ),
          ),
          const SizedBox(width: AuraDimensions.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuraTypography.headingSmall.copyWith(
                    fontSize: 15,
                    color: textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space1),
                Text(
                  metadata.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraTypography.bodySmall.copyWith(
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        metadata.platform,
                        style: AuraTypography.bodySmall.copyWith(
                          color: primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (metadata.duration != null) ...[
                      const SizedBox(width: AuraDimensions.space2),
                      Text(
                        Formatters.formatDuration(metadata.duration!),
                        style: AuraTypography.metricSmall.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.only(left: AuraDimensions.space2),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
