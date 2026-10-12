import 'package:equatable/equatable.dart';
import '../../data/models/download_task.dart';
import '../../data/models/media_metadata.dart';

class DownloadState extends Equatable {
  final List<DownloadTask> tasks;
  final MediaMetadata? previewMetadata;
  final bool isLoadingMetadata;
  final String? metadataError;
  final int concurrencyLimit;

  const DownloadState({
    this.tasks = const [],
    this.previewMetadata,
    this.isLoadingMetadata = false,
    this.metadataError,
    this.concurrencyLimit = 2,
  });

  List<DownloadTask> get activeTasks =>
      tasks.where((t) => !t.isTerminal).toList();

  List<DownloadTask> get completedTasks =>
      tasks.where((t) => t.status == DownloadStatus.completed).toList();

  int get queuedCount =>
      tasks.where((t) => t.status == DownloadStatus.queued).length;

  int get downloadingCount =>
      tasks.where((t) => t.status == DownloadStatus.downloading).length;

  DownloadState copyWith({
    List<DownloadTask>? tasks,
    MediaMetadata? previewMetadata,
    bool clearMetadata = false,
    bool? isLoadingMetadata,
    String? metadataError,
    bool clearError = false,
    int? concurrencyLimit,
  }) {
    return DownloadState(
      tasks: tasks ?? this.tasks,
      previewMetadata:
          clearMetadata ? null : (previewMetadata ?? this.previewMetadata),
      isLoadingMetadata: isLoadingMetadata ?? this.isLoadingMetadata,
      metadataError: clearError ? null : (metadataError ?? this.metadataError),
      concurrencyLimit: concurrencyLimit ?? this.concurrencyLimit,
    );
  }

  @override
  List<Object?> get props => [
        tasks,
        previewMetadata,
        isLoadingMetadata,
        metadataError,
        concurrencyLimit,
      ];
}

