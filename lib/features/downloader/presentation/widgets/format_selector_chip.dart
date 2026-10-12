import 'package:flutter/material.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Formato de descarga',
          style: TextStyle(
            color: AppColors.textSecondary,
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
          const Text(
            'Resolución de video',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VideoQuality>(
                value: availableQualities.contains(selectedQuality)
                    ? selectedQuality
                    : availableQualities.first,
                dropdownColor: AppColors.surfaceVariant,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                isExpanded: true,
                items: availableQualities.map((quality) {
                  return DropdownMenuItem<VideoQuality>(
                    value: quality,
                    child: Text(
                      quality.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

