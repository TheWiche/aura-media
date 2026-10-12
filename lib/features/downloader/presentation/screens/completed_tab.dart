import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';
import '../widgets/completed_task_card.dart';

class CompletedTab extends StatelessWidget {
  const CompletedTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final completedList = state.completedTasks;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // Header Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special_outlined, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${completedList.length} archivo${completedList.length == 1 ? "" : "s"} guardado${completedList.length == 1 ? "" : "s"}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (completedList.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: AppColors.textMuted),
                        label: const Text(
                          'Limpiar historial',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'No hay descargas completadas',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tus archivos de video y audio descargados aparecerán aquí para reproducirlos o compartirlos en cualquier momento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
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

