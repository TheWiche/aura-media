import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/download_task.dart';

class FormatSelectorChip extends StatelessWidget {
  final MediaType selectedMediaType;
  final VideoQuality selectedQuality;
  final ValueChanged<MediaType> onMediaTypeChanged;
  final ValueChanged<VideoQuality> onQualityChanged;
  final List<VideoQuality> availableQualities;

  const FormatSelectorChip({
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
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Formato de descarga',
          style: GoogleFonts.outfit(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        // Toggle Audio / Video
        Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                context: context,
                title: 'Video',
                subtitle: 'MP4 con audio',
                icon: Icons.movie_outlined,
                isSelected: selectedMediaType == MediaType.video,
                onTap: () => onMediaTypeChanged(MediaType.video),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeButton(
                context: context,
                title: 'Solo Audio',
                subtitle: 'M4A / MP3 (Alta calidad)',
                icon: Icons.music_note_outlined,
                isSelected: selectedMediaType == MediaType.audio,
                onTap: () => onMediaTypeChanged(MediaType.audio),
              ),
            ),
          ],
        ),

        // Quality selector when Video is chosen
        if (selectedMediaType == MediaType.video) ...[
          const SizedBox(height: 16),
          Text(
            'Resolución de video',
            style: GoogleFonts.outfit(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VideoQuality>(
                value: availableQualities.contains(selectedQuality)
                    ? selectedQuality
                    : availableQualities.first,
                dropdownColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                isExpanded: true,
                items: availableQualities.map((quality) {
                  return DropdownMenuItem<VideoQuality>(
                    value: quality,
                    child: Text(
                      quality.label,
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onQualityChanged(val);
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
