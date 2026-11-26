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
    final tokens = AuraThemeTokens.of(context);

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final completedList = state.completedTasks;

        return Column(
          children: [
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
                        color: tokens.audio.withValues(alpha: 0.15),
                        borderRadius: AuraDimensions.radiusSmall,
                      ),
                      child: Icon(
                        Icons.folder_special_rounded,
                        color: tokens.audio,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AuraDimensions.space3),
                    Expanded(
                      child: Text(
                        '${completedList.length} archivo${completedList.length == 1 ? "" : "s"} guardado${completedList.length == 1 ? "" : "s"}',
                        style: AuraTypography.metricSmall.copyWith(
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (completedList.isNotEmpty)
                      TextButton.icon(
                        icon: Icon(
                          Icons.cleaning_services_rounded,
                          size: 16,
                          color: tokens.textSecondary,
                        ),
                        label: Text(
                          'Limpiar',
                          style: AuraTypography.label.copyWith(
                            color: tokens.textSecondary,
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

            Expanded(
              child: completedList.isEmpty
                  ? _buildEmptyState(tokens)
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

  Widget _buildEmptyState(AuraThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuraDimensions.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: tokens.card,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.divider),
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 46,
                color: tokens.audio,
              ),
            ),
            const SizedBox(height: AuraDimensions.space5),
            Text(
              'No hay descargas completadas',
              style: AuraTypography.headingSmall
                  .copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: AuraDimensions.space2),
            Text(
              'Tus archivos de audio y video aparecerán aquí para reproducirlos o compartirlos.',
              textAlign: TextAlign.center,
              style: AuraTypography.bodySmall.copyWith(
                color: tokens.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
