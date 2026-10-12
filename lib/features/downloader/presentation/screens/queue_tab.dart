import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return BlocBuilder<DownloadBloc, DownloadState>(
      builder: (context, state) {
        final activeList = state.activeTasks;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // Concurrency & Header Banner
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
                    const Icon(Icons.sync_alt_rounded, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Límite de concurrencia:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Concurrency dropdown selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: state.concurrencyLimit,
                          dropdownColor: AppColors.surfaceVariant,
                          isDense: true,
                          items: [1, 2, 3, 4].map((limit) {
                            return DropdownMenuItem<int>(
                              value: limit,
                              child: Text(
                                '$limit a la vez',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
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
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay descargas en curso',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Las tareas que agregues aparecerán aquí. La app descargará de forma simultánea según tu límite configurado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onNavigateToHome,
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Agregar un enlace'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

