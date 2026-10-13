import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import '../widgets/completed_task_card.dart';

class CompletedTab extends StatelessWidget {
  const CompletedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final completedList = state.completedTasks;

        return Column(
          children: [
            // Header Summary Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_special_rounded, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${completedList.length} archivo${completedList.length == 1 ? "" : "s"} guardado${completedList.length == 1 ? "" : "s"}',
                      style: GoogleFonts.outfit(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (completedList.isNotEmpty)
                    TextButton.icon(
                      icon: Icon(
                        Icons.cleaning_services_rounded,
                        size: 16,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      label: Text(
                        'Limpiar',
                        style: GoogleFonts.outfit(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        context.read<DownloadBloc>().add(const ClearCompletedEvent());
                      },
                    ),
                ],
              ),
            ),

            // Files List or Empty State
            Expanded(
              child: completedList.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: completedList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No hay descargas completadas',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus archivos de video y audio aparecerán aquí para reproducirlos o compartirlos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
