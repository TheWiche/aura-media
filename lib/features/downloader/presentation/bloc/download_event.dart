import 'package:equatable/equatable.dart';
import '../../data/models/download_task.dart';
import '../../data/models/media_metadata.dart';

abstract class DownloadEvent extends Equatable {
  const DownloadEvent();

  @override
  List<Object?> get props => [];
}

class FetchMetadataEvent extends DownloadEvent {
  final String url;
  const FetchMetadataEvent(this.url);

  @override
  List<Object?> get props => [url];
}

class ClearMetadataEvent extends DownloadEvent {
  const ClearMetadataEvent();
}

class EnqueueDownloadEvent extends DownloadEvent {
  final String url;
  final MediaType mediaType;
  final VideoQuality quality;
  final MediaMetadata? metadata;

  const EnqueueDownloadEvent({
    required this.url,
    required this.mediaType,
    this.quality = VideoQuality.best,
    this.metadata,
  });

  @override
  List<Object?> get props => [url, mediaType, quality, metadata];
}

class PauseDownloadEvent extends DownloadEvent {
  final String taskId;
  const PauseDownloadEvent(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class ResumeDownloadEvent extends DownloadEvent {
  final String taskId;
  const ResumeDownloadEvent(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class CancelDownloadEvent extends DownloadEvent {
  final String taskId;
  const CancelDownloadEvent(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class RetryDownloadEvent extends DownloadEvent {
  final String taskId;
  const RetryDownloadEvent(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class RemoveTaskEvent extends DownloadEvent {
  final String taskId;
  final bool deletePhysicalFile;

  const RemoveTaskEvent(this.taskId, {this.deletePhysicalFile = false});

  @override
  List<Object?> get props => [taskId, deletePhysicalFile];
}

class ClearCompletedEvent extends DownloadEvent {
  const ClearCompletedEvent();
}

class UpdateConcurrencyLimitEvent extends DownloadEvent {
  final int limit;
  const UpdateConcurrencyLimitEvent(this.limit);

  @override
  List<Object?> get props => [limit];
}

class TasksUpdatedEvent extends DownloadEvent {
  final List<DownloadTask> tasks;
  const TasksUpdatedEvent(this.tasks);

  @override
  List<Object?> get props => [tasks];
}

