import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              height: 66,
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              child: metadata.thumbnailUrl != null
                  ? Image.network(
                      metadata.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        Icons.movie_creation_outlined,
                        color: AppColors.darkTextMuted,
                      ),
                    )
                  : const Icon(
                      Icons.video_library_outlined,
                      color: AppColors.darkTextMuted,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  metadata.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        metadata.platform,
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (metadata.duration != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        Formatters.formatDuration(metadata.duration!),
                        style: GoogleFonts.outfit(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Clear button
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
