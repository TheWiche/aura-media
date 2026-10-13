import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import '../widgets/download_task_card.dart';

class QueueTab extends StatelessWidget {
  final VoidCallback onNavigateToHome;

  const QueueTab({
    super.key,
    required this.onNavigateToHome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final activeList = state.activeTasks;

        return Column(
          children: [
            // Concurrency & Header Banner
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
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sync_alt_rounded, color: AppColors.secondary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Límite de concurrencia:',
                      style: GoogleFonts.outfit(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Concurrency dropdown selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: state.concurrencyLimit,
                        dropdownColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 18),
                        isDense: true,
                        items: [1, 2, 3, 4].map((limit) {
                          return DropdownMenuItem<int>(
                            value: limit,
                            child: Text(
                              '$limit a la vez',
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            context.read<DownloadBloc>().add(UpdateConcurrencyLimitEvent(val));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Queue List or Empty State
            Expanded(
              child: activeList.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: activeList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final task = activeList[index];
                        return DownloadTaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onPause: () {
                            context.read<DownloadBloc>().add(PauseDownloadEvent(task.id));
                          },
                          onResume: () {
                            context.read<DownloadBloc>().add(ResumeDownloadEvent(task.id));
                          },
                          onCancel: () {
                            context.read<DownloadBloc>().add(CancelDownloadEvent(task.id));
                          },
                          onRetry: () {
                            context.read<DownloadBloc>().add(RetryDownloadEvent(task.id));
                          },
                          onRemove: () {
                            context.read<DownloadBloc>().add(RemoveTaskEvent(task.id));
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
                Icons.check_circle_outline_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No hay descargas en curso',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las tareas que agregues aparecerán aquí y se procesarán según el límite configurado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onNavigateToHome,
              icon: const Icon(Icons.add_link_rounded, size: 18),
              label: Text(
                'Agregar un enlace',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
