import 'package:flutter/material.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';
import '../../core/theme/aura_typography.dart';
import '../../core/utils/formatters.dart';
import '../../features/downloader/data/models/download_task.dart';
import '../../features/downloader/data/models/media_metadata.dart';

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

  // Extended detailed stream options
  final List<VideoStreamOption> videoOptions;
  final VideoStreamOption? selectedVideoOption;
  final ValueChanged<VideoStreamOption>? onVideoOptionChanged;
  final List<AudioStreamOption> audioOptions;
  final AudioStreamOption? selectedAudioOption;
  final ValueChanged<AudioStreamOption>? onAudioOptionChanged;
  final AudioFileFormat? selectedAudioFormat;
  final ValueChanged<AudioFileFormat>? onAudioFormatChanged;
  final bool isResolvingFormats;

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
    this.videoOptions = const [],
    this.selectedVideoOption,
    this.onVideoOptionChanged,
    this.audioOptions = const [],
    this.selectedAudioOption,
    this.onAudioOptionChanged,
    this.selectedAudioFormat,
    this.onAudioFormatChanged,
    this.isResolvingFormats = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);
    final effectiveQuality = availableQualities.contains(selectedQuality)
        ? selectedQuality
        : availableQualities.first;

    final activeAudioExt = selectedAudioOption?.extension.toUpperCase() ??
        selectedAudioFormat?.shortLabel ??
        audioExtensionLabel;

    final audioSubtitle = selectedAudioOption != null
        ? '$activeAudioExt · ${selectedAudioOption!.bitrateKbps} kbps · ${Formatters.formatBytes(selectedAudioOption!.sizeBytes)}'
        : (audioSizeBytes != null
            ? '$activeAudioExt · ${Formatters.formatBytes(audioSizeBytes!)}'
            : '$activeAudioExt · Alta calidad');

    final videoSubtitle = selectedVideoOption != null
        ? '${selectedVideoOption!.container.toUpperCase()} · ${selectedVideoOption!.videoCodec} · ${Formatters.formatBytes(selectedVideoOption!.totalSizeBytes)}'
        : (videoSizeBytes != null
            ? 'MP4 · ${Formatters.formatBytes(videoSizeBytes!)}'
            : 'MP4 · ${effectiveQuality.shortLabel}');

    // Matching video options for active resolution
    final matchingVideoOpts = _matchingVideoOptions(effectiveQuality);
    final activeAudioFormat =
        selectedAudioFormat ?? SettingsService.instance.getAudioFormat();
    final matchingAudioOpts =
        audioOptions.where((o) => o.format == activeAudioFormat).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'FORMATO DE DESCARGA',
              style: AuraTypography.bodySmall.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            if (isResolvingFormats) ...[
              const SizedBox(width: AuraDimensions.space2),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Calculando opciones...',
                style: AuraTypography.bodySmall.copyWith(
                  color: tokens.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AuraDimensions.space2),
        Row(
          children: [
            Expanded(
              child: _FormatTile(
                title: 'Solo Audio',
                subtitle: audioSubtitle,
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
                subtitle: videoSubtitle,
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

        // ─── AUDIO FORMAT & BITRATE OPTIONS ─────────────────────────────────
        if (selectedMediaType == MediaType.audio) ...[
          if (onAudioFormatChanged != null) ...[
            const SizedBox(height: AuraDimensions.space3),
            Text(
              'Formato de audio',
              style: AuraTypography.label.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AuraDimensions.space2),
            Row(
              children: AudioFileFormat.values.map((fmt) {
                final selected = fmt == activeAudioFormat;
                final isLast = fmt == AudioFileFormat.values.last;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: _FormatPillChip(
                      title: fmt.shortLabel,
                      subtitle: switch (fmt) {
                        AudioFileFormat.mp3 => 'Compatible',
                        AudioFileFormat.m4a => 'AAC Nativo',
                        AudioFileFormat.webm => 'Opus WebM',
                      },
                      selected: selected,
                      accentColor: tokens.audio,
                      tokens: tokens,
                      onTap: () => onAudioFormatChanged!(fmt),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (matchingAudioOpts.isNotEmpty && onAudioOptionChanged != null) ...[
            const SizedBox(height: AuraDimensions.space2),
            Text(
              'Calidad y bitrate',
              style: AuraTypography.label.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AuraDimensions.space1 + 2),
            if (compact)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: matchingAudioOpts.map((opt) {
                    final isSelected = selectedAudioOption?.id == opt.id ||
                        (selectedAudioOption == null &&
                            opt == matchingAudioOpts.first);
                    final langPart = (opt.trackLanguage != null &&
                            opt.trackLanguage!.isNotEmpty)
                        ? ' · ${opt.trackLanguage}'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CompactOptionChip(
                        title: '${opt.qualityTier} · ${opt.bitrateKbps}k$langPart',
                        subtitle:
                            '${opt.codecLabel} · ${Formatters.formatBytes(opt.sizeBytes)}',
                        selected: isSelected,
                        accentColor: tokens.audio,
                        tokens: tokens,
                        onTap: () => onAudioOptionChanged!(opt),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              ...matchingAudioOpts.map((opt) {
                final isSelected = selectedAudioOption?.id == opt.id ||
                    (selectedAudioOption == null &&
                        opt == matchingAudioOpts.first);
                final langPart = (opt.trackLanguage != null &&
                        opt.trackLanguage!.isNotEmpty)
                    ? ' · ${opt.trackLanguage}'
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DetailedStreamRow(
                    title:
                        '${opt.qualityTier} · ${opt.bitrateKbps} kbps$langPart',
                    subtitle: '${opt.codecLabel} · ${opt.note}',
                    badge: opt.extension.toUpperCase(),
                    sizeBytes: opt.sizeBytes,
                    selected: isSelected,
                    accentColor: tokens.audio,
                    tokens: tokens,
                    compact: compact,
                    onTap: () => onAudioOptionChanged!(opt),
                  ),
                );
              }),
          ],
        ],

        // ─── VIDEO RESOLUTION & CODEC OPTIONS ───────────────────────────────
        if (selectedMediaType == MediaType.video) ...[
          const SizedBox(height: AuraDimensions.space3),
          Text(
            'Resolución de video',
            style: AuraTypography.label.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: AuraDimensions.space2),
          if (compact)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableQualities.map((quality) {
                  final selected = quality == effectiveQuality;
                  final hasHighFps = quality != VideoQuality.best &&
                      videoOptions.any(
                          (o) => o.quality == quality && o.fps >= 48);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _QualityChip(
                      quality: quality,
                      selected: selected,
                      hasHighFps: hasHighFps,
                      tokens: tokens,
                      onTap: () => onQualityChanged(quality),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Wrap(
              spacing: AuraDimensions.space2,
              runSpacing: AuraDimensions.space2,
              children: availableQualities.map((quality) {
                final selected = quality == effectiveQuality;
                final hasHighFps = quality != VideoQuality.best &&
                    videoOptions
                        .any((o) => o.quality == quality && o.fps >= 48);
                return _QualityChip(
                  quality: quality,
                  selected: selected,
                  hasHighFps: hasHighFps,
                  tokens: tokens,
                  onTap: () => onQualityChanged(quality),
                );
              }).toList(),
            ),

          if (matchingVideoOpts.isNotEmpty && onVideoOptionChanged != null) ...[
            const SizedBox(height: AuraDimensions.space2),
            Text(
              'Formato y códec',
              style: AuraTypography.label.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: AuraDimensions.space1 + 2),
            if (compact)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: matchingVideoOpts.map((opt) {
                    final isSelected = selectedVideoOption?.id == opt.id ||
                        (selectedVideoOption == null &&
                            opt == matchingVideoOpts.first);
                    final fpsTag = opt.isMuxed ? 'Directo' : '${opt.fps}fps';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CompactOptionChip(
                        title:
                            '${opt.container.toUpperCase()} · ${opt.videoCodec} + ${opt.audioCodec}',
                        subtitle:
                            '$fpsTag · ${Formatters.formatBytes(opt.totalSizeBytes)}',
                        selected: isSelected,
                        accentColor: tokens.primary,
                        tokens: tokens,
                        onTap: () => onVideoOptionChanged!(opt),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              ...matchingVideoOpts.map((opt) {
                final isSelected = selectedVideoOption?.id == opt.id ||
                    (selectedVideoOption == null &&
                        opt == matchingVideoOpts.first);
                final fpsLabel = '${opt.fps}fps';
                final extraTag = opt.isHdr
                    ? '$fpsLabel · HDR'
                    : (opt.isMuxed ? '1 paso · directo' : fpsLabel);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DetailedStreamRow(
                    title:
                        '${opt.container.toUpperCase()} · ${opt.videoCodec} + ${opt.audioCodec}',
                    subtitle: '$extraTag · ${opt.compatibilityNote}',
                    badge: opt.isMuxed ? 'RÁPIDO' : '${opt.height}p',
                    sizeBytes: opt.totalSizeBytes,
                    selected: isSelected,
                    accentColor: tokens.primary,
                    tokens: tokens,
                    compact: compact,
                    onTap: () => onVideoOptionChanged!(opt),
                  ),
                );
              }),
          ],
        ],
      ],
    );
  }

  List<VideoStreamOption> _matchingVideoOptions(VideoQuality quality) {
    if (videoOptions.isEmpty) return const [];
    if (quality == VideoQuality.best) {
      final topH = videoOptions.first.height;
      return videoOptions.where((o) => o.height == topH).toList();
    }
    final exact = videoOptions.where((o) => o.quality == quality).toList();
    if (exact.isNotEmpty) return exact;
    final targetH = quality.heightPixels;
    if (targetH != null) {
      final lower = videoOptions.where((o) => o.height <= targetH).toList();
      if (lower.isNotEmpty) {
        final h = lower.first.height;
        return lower.where((o) => o.height == h).toList();
      }
    }
    final topH = videoOptions.first.height;
    return videoOptions.where((o) => o.height == topH).toList();
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
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
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

class _FormatPillChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final AuraThemeTokens tokens;
  final VoidCallback onTap;

  const _FormatPillChip({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accentColor.withValues(alpha: tokens.isDark ? 0.18 : 0.12)
          : tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: AuraDimensions.radiusSmall,
        side: BorderSide(
          color: selected ? accentColor : tokens.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AuraDimensions.radiusSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraTypography.metricSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? accentColor : tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraTypography.bodySmall.copyWith(
                  fontSize: 9.5,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailedStreamRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final int sizeBytes;
  final bool selected;
  final Color accentColor;
  final AuraThemeTokens tokens;
  final bool compact;
  final VoidCallback onTap;

  const _DetailedStreamRow({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.sizeBytes,
    required this.selected,
    required this.accentColor,
    required this.tokens,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accentColor.withValues(alpha: tokens.isDark ? 0.14 : 0.09)
          : tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: AuraDimensions.radiusSmall,
        side: BorderSide(
          color: selected ? accentColor : tokens.divider,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AuraDimensions.radiusSmall,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AuraDimensions.space3,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? accentColor : tokens.disabled,
                    width: selected ? 5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: AuraDimensions.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraTypography.label.copyWith(
                              fontSize: compact ? 12.5 : 13,
                              color: selected
                                  ? tokens.textPrimary
                                  : tokens.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badge,
                            style: AuraTypography.metricSmall.copyWith(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraDimensions.space2),
              Text(
                sizeBytes > 0 ? Formatters.formatBytes(sizeBytes) : '...',
                style: AuraTypography.metricSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? accentColor : tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  final VideoQuality quality;
  final bool selected;
  final bool hasHighFps;
  final AuraThemeTokens tokens;
  final VoidCallback onTap;

  const _QualityChip({
    required this.quality,
    required this.selected,
    required this.hasHighFps,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: onTap,
        borderRadius: AuraDimensions.radiusSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraDimensions.space3,
            vertical: AuraDimensions.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                quality.shortLabel,
                style: AuraTypography.metricSmall.copyWith(
                  color: selected ? tokens.primary : tokens.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (hasHighFps) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: (selected ? tokens.primary : tokens.video)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '60',
                    style: AuraTypography.metricSmall.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected ? tokens.primary : tokens.video,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactOptionChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final AuraThemeTokens tokens;
  final VoidCallback onTap;

  const _CompactOptionChip({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accentColor.withValues(alpha: tokens.isDark ? 0.18 : 0.12)
          : tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: AuraDimensions.radiusSmall,
        side: BorderSide(
          color: selected ? accentColor : tokens.divider,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AuraDimensions.radiusSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AuraTypography.label.copyWith(
                  fontSize: 11.5,
                  color: selected ? accentColor : tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: AuraTypography.metricSmall.copyWith(
                  fontSize: 10,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
