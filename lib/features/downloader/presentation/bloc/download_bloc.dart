import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:medias_download/core/services/permission_service.dart';
import 'package:medias_download/features/downloader/data/datasources/generic_extractor.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/features/downloader/domain/queue/download_queue_manager.dart';
import 'download_event.dart';
import 'download_state.dart';

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final DownloadQueueManager _queueManager;
  final YoutubeExtractor _youtubeExtractor;
  final GenericExtractor _genericExtractor;
  final PermissionService _permissionService;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<DownloadTask>>? _queueSubscription;

  DownloadBloc({
    DownloadQueueManager? queueManager,
    YoutubeExtractor? youtubeExtractor,
    GenericExtractor? genericExtractor,
    PermissionService? permissionService,
  })  : _queueManager = queueManager ?? DownloadQueueManager.instance,
        _youtubeExtractor = youtubeExtractor ?? YoutubeExtractor(),
        _genericExtractor = genericExtractor ?? GenericExtractor(),
        _permissionService = permissionService ?? PermissionService.instance,
        super(DownloadState(
          tasks: (queueManager ?? DownloadQueueManager.instance).currentTasks,
          concurrencyLimit: (queueManager ?? DownloadQueueManager.instance).maxConcurrentDownloads,
        )) {
    on<FetchMetadataEvent>(_onFetchMetadata);
    on<ClearMetadataEvent>(_onClearMetadata);
    on<EnqueueDownloadEvent>(_onEnqueueDownload);
    on<PauseDownloadEvent>(_onPauseDownload);
    on<ResumeDownloadEvent>(_onResumeDownload);
    on<CancelDownloadEvent>(_onCancelDownload);
    on<RetryDownloadEvent>(_onRetryDownload);
    on<RemoveTaskEvent>(_onRemoveTask);
    on<ClearCompletedEvent>(_onClearCompleted);
    on<UpdateConcurrencyLimitEvent>(_onUpdateConcurrencyLimit);
    on<TasksUpdatedEvent>(_onTasksUpdated);

    // Listen to background queue changes
    _queueSubscription = _queueManager.tasksStream.listen((tasks) {
      add(TasksUpdatedEvent(tasks));
    });
  }

  Future<void> _onFetchMetadata(
    FetchMetadataEvent event,
    Emitter<DownloadState> emit,
  ) async {
    final url = event.url.trim();
    if (url.isEmpty) return;

    emit(state.copyWith(
      isLoadingMetadata: true,
      clearError: true,
      clearMetadata: true,
    ));

    try {
      if (YoutubeExtractor.isYoutubeUrl(url)) {
        final meta = await _youtubeExtractor.fetchMetadata(url);
        emit(state.copyWith(
          isLoadingMetadata: false,
          previewMetadata: meta,
        ));
      } else {
        final meta = await _genericExtractor.fetchMetadata(url);
        emit(state.copyWith(
          isLoadingMetadata: false,
          previewMetadata: meta,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingMetadata: false,
        metadataError: 'No se pudo obtener información del enlace: ${e.toString().replaceFirst("Exception: ", "")}',
      ));
    }
  }

  void _onClearMetadata(
    ClearMetadataEvent event,
    Emitter<DownloadState> emit,
  ) {
    emit(state.copyWith(clearMetadata: true, clearError: true));
  }

  Future<void> _onEnqueueDownload(
    EnqueueDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    // Request permissions proactively
    await _permissionService.requestStoragePermission();
    await _permissionService.requestNotificationPermission();

    final taskId = _uuid.v4();
    final notifId = taskId.hashCode.abs() % 100000;
    final extension = event.mediaType == MediaType.audio ? 'm4a' : 'mp4';
    final title = event.metadata?.title ?? 'Descarga_${DateTime.now().millisecondsSinceEpoch}';

    final task = DownloadTask(
      id: taskId,
      notificationId: notifId,
      url: event.url.trim(),
      title: title,
      author: event.metadata?.author,
      thumbnailUrl: event.metadata?.thumbnailUrl,
      mediaType: event.mediaType,
      quality: event.quality,
      fileExtension: extension,
      createdAt: DateTime.now(),
      status: DownloadStatus.queued,
    );

    _queueManager.addTask(task);

    // Reset metadata preview
    emit(state.copyWith(clearMetadata: true));
  }

  Future<void> _onPauseDownload(
    PauseDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    await _queueManager.pauseTask(event.taskId);
  }

  void _onResumeDownload(
    ResumeDownloadEvent event,
    Emitter<DownloadState> emit,
  ) {
    _queueManager.resumeTask(event.taskId);
  }

  Future<void> _onCancelDownload(
    CancelDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    await _queueManager.cancelTask(event.taskId);
  }

  void _onRetryDownload(
    RetryDownloadEvent event,
    Emitter<DownloadState> emit,
  ) {
    _queueManager.retryTask(event.taskId);
  }

  Future<void> _onRemoveTask(
    RemoveTaskEvent event,
    Emitter<DownloadState> emit,
  ) async {
    await _queueManager.removeTask(event.taskId, deletePhysicalFile: event.deletePhysicalFile);
  }

  void _onClearCompleted(
    ClearCompletedEvent event,
    Emitter<DownloadState> emit,
  ) {
    _queueManager.clearCompleted();
  }

  void _onUpdateConcurrencyLimit(
    UpdateConcurrencyLimitEvent event,
    Emitter<DownloadState> emit,
  ) {
    _queueManager.setMaxConcurrency(event.limit);
    emit(state.copyWith(concurrencyLimit: event.limit));
  }

  void _onTasksUpdated(
    TasksUpdatedEvent event,
    Emitter<DownloadState> emit,
  ) {
    emit(state.copyWith(tasks: event.tasks));
  }

  @override
  Future<void> close() {
    _queueSubscription?.cancel();
    return super.close();
  }
}

