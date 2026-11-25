import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/aura_colors.dart';
import '../../../../core/theme/aura_dimensions.dart';
import '../../../../core/theme/aura_typography.dart';
import '../../../../shared/widgets/aura_card.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import '../widgets/completed_task_card.dart';

class CompletedTab extends StatelessWidget {
  const CompletedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioColor = AuraColors.audio(isDark);
    final textSecondary = AuraColors.textSecondary(isDark);

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final completedList = state.completedTasks;

        return Column(
          children: [
            // Header Summary Banner
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
                        color: audioColor.withValues(alpha: 0.15),
                        borderRadius: AuraDimensions.radiusSmall,
                      ),
                      child: Icon(
                        Icons.folder_special_rounded,
                        color: audioColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AuraDimensions.space3),
                    Expanded(
                      child: Text(
                        '${completedList.length} archivo${completedList.length == 1 ? "" : "s"} guardado${completedList.length == 1 ? "" : "s"}',
                        style: AuraTypography.metricSmall.copyWith(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (completedList.isNotEmpty)
                      TextButton.icon(
                        icon: Icon(
                          Icons.cleaning_services_rounded,
                          size: 16,
                          color: textSecondary,
                        ),
                        label: Text(
                          'Limpiar',
                          style: AuraTypography.label.copyWith(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          context
                              .read<DownloadBloc>()
                              .add(const ClearCompletedEvent());
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Files List or Empty State
            Expanded(
              child: completedList.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AuraDimensions.space4,
                        AuraDimensions.space2,
                        AuraDimensions.space4,
                        AuraDimensions.space4,
                      ),
                      itemCount: completedList.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AuraDimensions.space3),
                      itemBuilder: (context, index) {
                        final task = completedList[index];
                        return CompletedTaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onRemove: (deletePhysicalFile) {
                            context.read<DownloadBloc>().add(
                                  RemoveTaskEvent(
                                    task.id,
                                    deletePhysicalFile: deletePhysicalFile,
                                  ),
                                );
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
    final audioColor = AuraColors.audio(isDark);

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
                Icons.folder_open_rounded,
                size: 46,
                color: audioColor,
              ),
            ),
            const SizedBox(height: AuraDimensions.space5),
            Text(
              'No hay descargas completadas',
              style: AuraTypography.headingSmall.copyWith(color: textPrimary),
            ),
            const SizedBox(height: AuraDimensions.space2),
            Text(
              'Tus archivos de audio y video aparecerán aquí para reproducirlos o compartirlos.',
              textAlign: TextAlign.center,
              style: AuraTypography.bodySmall.copyWith(
                color: textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
