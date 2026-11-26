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
    final tokens = AuraThemeTokens.of(context);
    final stageLabel = switch (metadata.analysisStage) {
      AnalysisStage.instant => 'Conectando...',
      AnalysisStage.basicInfo => 'Calculando formatos...',
      AnalysisStage.streamsReady || AnalysisStage.enriching => 'Refinando...',
      AnalysisStage.complete => null,
    };

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
              color: tokens.primary.withValues(alpha: 0.12),
              child: metadata.thumbnailUrl != null
                  ? Image.network(
                      metadata.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.movie_creation_outlined,
                        color: tokens.textSecondary,
                      ),
                    )
                  : Icon(
                      Icons.video_library_outlined,
                      color: tokens.textSecondary,
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
                    color: tokens.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space1),
                Text(
                  metadata.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraTypography.bodySmall.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: AuraDimensions.space2),
                Wrap(
                  spacing: AuraDimensions.space2,
                  runSpacing: AuraDimensions.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        metadata.platform,
                        style: AuraTypography.bodySmall.copyWith(
                          color: tokens.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (metadata.duration != null)
                      Text(
                        Formatters.formatDuration(metadata.duration!),
                        style: AuraTypography.metricSmall.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    if (stageLabel != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: tokens.primary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            stageLabel,
                            style: AuraTypography.bodySmall.copyWith(
                              color: tokens.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else if (metadata.videoOptions.isNotEmpty)
                      Text(
                        '${metadata.videoOptions.length} formatos · ${metadata.audioOptions.length} audios',
                        style: AuraTypography.bodySmall.copyWith(
                          color: tokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
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
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
