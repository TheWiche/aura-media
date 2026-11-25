import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../shared/widgets/aura_button.dart';
import '../../../../shared/widgets/aura_card.dart';
import '../../../../shared/widgets/aura_download_card.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';

class QueueTab extends StatelessWidget {
  final VoidCallback onNavigateToHome;

  const QueueTab({
    super.key,
    required this.onNavigateToHome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final primary = AuraColors.primary(isDark);
    final audioColor = AuraColors.audio(isDark);

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final activeList = state.activeTasks;

        return Column(
          children: [
            // Concurrency selector header card
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraDimensions.space4,
                AuraDimensions.space3,
                AuraDimensions.space4,
                AuraDimensions.space2,
              ),
              child: AuraCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraDimensions.space4,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AuraColors.secondary(isDark)
                            .withValues(alpha: 0.15),
                        borderRadius: AuraDimensions.radiusSmall,
                      ),
                      child: Icon(
                        Icons.sync_alt_rounded,
                        color: AuraColors.secondary(isDark),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AuraDimensions.space3),
                    Expanded(
                      child: Text(
                        'Límite de concurrencia',
                        style: AuraTypography.label.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AuraColors.darkSurface
                            : AuraColors.lightBackground,
                        borderRadius: AuraDimensions.radiusSmall,
                        border: Border.all(
                          color: AuraColors.divider(isDark),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: state.concurrencyLimit,
                          dropdownColor: AuraColors.surface(isDark),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: primary,
                            size: 18,
                          ),
                          isDense: true,
                          items: [1, 2, 3, 4].map((limit) {
                            return DropdownMenuItem<int>(
                              value: limit,
                              child: Text(
                                '$limit a la vez',
                                style: AuraTypography.metricSmall.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              context
                                  .read<DownloadBloc>()
                                  .add(UpdateConcurrencyLimitEvent(val));
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Active queue list or empty state
            Expanded(
              child: activeList.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AuraDimensions.space4,
                        AuraDimensions.space2,
                        AuraDimensions.space4,
                        AuraDimensions.space4,
                      ),
                      itemCount: activeList.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AuraDimensions.space3),
                      itemBuilder: (context, index) {
                        if (index == activeList.length) {
                          return AuraCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AuraDimensions.space4,
                              vertical: AuraDimensions.space3,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: audioColor.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: audioColor,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: AuraDimensions.space3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Descargas en segundo plano',
                                        style: AuraTypography.label.copyWith(
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Puedes seguir usando otras apps',
                                        style: AuraTypography.bodySmall
                                            .copyWith(color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.bolt_rounded,
                                  color: primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          );
                        }

                        final task = activeList[index];
                        return AuraDownloadCard(
                          key: ValueKey(task.id),
                          task: task,
                          onPause: () {
                            context
                                .read<DownloadBloc>()
                                .add(PauseDownloadEvent(task.id));
                          },
                          onResume: () {
                            context
                                .read<DownloadBloc>()
                                .add(ResumeDownloadEvent(task.id));
                          },
                          onCancel: () {
                            context
                                .read<DownloadBloc>()
                                .add(CancelDownloadEvent(task.id));
                          },
                          onRetry: () {
                            context
                                .read<DownloadBloc>()
                                .add(RetryDownloadEvent(task.id));
                          },
                          onRemove: () {
                            context
                                .read<DownloadBloc>()
                                .add(RemoveTaskEvent(task.id));
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final textPrimary = AuraColors.textPrimary(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);
    final primary = AuraColors.primary(isDark);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuraDimensions.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AuraColors.card(isDark),
                shape: BoxShape.circle,
                border: Border.all(color: AuraColors.divider(isDark)),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 46,
                color: primary,
              ),
            ),
            const SizedBox(height: AuraDimensions.space5),
            Text(
              'No hay descargas en curso',
              style: AuraTypography.headingSmall.copyWith(color: textPrimary),
            ),
            const SizedBox(height: AuraDimensions.space2),
            Text(
              'Las tareas que agregues aparecerán aquí y se procesarán según el límite configurado.',
              textAlign: TextAlign.center,
              style: AuraTypography.bodySmall.copyWith(
                color: textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AuraDimensions.space6),
            SizedBox(
              width: 220,
              child: AuraButton(
                label: 'Agregar un enlace',
                icon: Icons.add_link_rounded,
                onPressed: onNavigateToHome,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
