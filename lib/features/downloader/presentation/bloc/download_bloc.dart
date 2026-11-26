import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:uuid/uuid.dart';
import 'package:medias_download/core/services/background_service.dart';
import 'package:medias_download/core/services/permission_service.dart';
import 'package:medias_download/core/services/settings_service.dart';
import 'package:medias_download/core/services/task_persistence_service.dart';
import 'package:medias_download/features/downloader/data/datasources/generic_extractor.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/features/downloader/data/models/media_metadata.dart';
import 'package:medias_download/features/downloader/domain/queue/download_queue_manager.dart';
import 'download_event.dart';
import 'download_state.dart';

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final DownloadQueueManager _queueManager;
  final YoutubeExtractor _youtubeExtractor;
  final GenericExtractor _genericExtractor;
  final PermissionService _permissionService;
  final BackgroundService _backgroundService;
  final bool _useForegroundIsolate;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<DownloadTask>>? _queueSubscription;
  bool _taskDataCallbackAttached = false;
  int _analysisGeneration = 0;

  DownloadBloc({
    DownloadQueueManager? queueManager,
    YoutubeExtractor? youtubeExtractor,
    GenericExtractor? genericExtractor,
    PermissionService? permissionService,
    BackgroundService? backgroundService,
    bool? useForegroundIsolate,
  })  : _queueManager = queueManager ?? DownloadQueueManager.instance,
        _youtubeExtractor = youtubeExtractor ?? YoutubeExtractor(),
        _genericExtractor = genericExtractor ?? GenericExtractor(),
        _permissionService = permissionService ?? PermissionService.instance,
        _backgroundService = backgroundService ?? BackgroundService.instance,
        _useForegroundIsolate =
            useForegroundIsolate ?? (Platform.isAndroid && queueManager == null),
        super(DownloadState(
          tasks: (queueManager ?? DownloadQueueManager.instance).currentTasks,
          concurrencyLimit: _readInitialConcurrency(queueManager),
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
    on<SyncTasksEvent>(_onSyncTasks);

    if (_useForegroundIsolate) {
      _initForegroundCommunication();
      add(const SyncTasksEvent());
    } else {
      _queueSubscription = _queueManager.tasksStream.listen((tasks) {
        add(TasksUpdatedEvent(tasks));
      });
    }
  }

  static int _readInitialConcurrency(DownloadQueueManager? injected) {
    if (injected != null) return injected.maxConcurrentDownloads;
    try {
      return SettingsService.instance.getMaxConcurrentDownloads();
    } catch (_) {
      return DownloadQueueManager.instance.maxConcurrentDownloads;
    }
  }

  void _initForegroundCommunication() {
    if (_taskDataCallbackAttached) return;
    _taskDataCallbackAttached = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveForegroundData);
  }

  void _onReceiveForegroundData(Object data) {
    if (isClosed || data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['type'] == 'tasks' && map['tasks'] is List) {
      final rawList = map['tasks'] as List<dynamic>;
      final parsed = rawList
          .whereType<Map>()
          .map((e) => DownloadTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      add(TasksUpdatedEvent(parsed));
    }
  }

  Future<void> _onSyncTasks(
    SyncTasksEvent event,
    Emitter<DownloadState> emit,
  ) async {
    if (!_useForegroundIsolate) return;
    try {
      final persisted = await TaskPersistenceService.instance.loadTasks();
      emit(state.copyWith(
        tasks: persisted,
        concurrencyLimit: SettingsService.instance.getMaxConcurrentDownloads(),
      ));
      await _backgroundService.requestSync();
    } catch (_) {}
  }

  Future<void> _onFetchMetadata(
    FetchMetadataEvent event,
    Emitter<DownloadState> emit,
  ) async {
    final url = event.url.trim();
    if (url.isEmpty) return;

    final generation = ++_analysisGeneration;

    emit(state.copyWith(
      isLoadingMetadata: true,
      clearError: true,
      clearMetadata: true,
    ));

    try {
      if (YoutubeExtractor.isYoutubeUrl(url)) {
        final meta = await _youtubeExtractor.fetchMetadataProgressive(
          url,
          onProgress: (partial) {
            if (isClosed || emit.isDone || generation != _analysisGeneration) {
              return;
            }
            emit(state.copyWith(
              isLoadingMetadata: !partial.analysisStage.hasStreams,
              previewMetadata: partial,
              clearError: true,
            ));
          },
        );
        if (isClosed || emit.isDone || generation != _analysisGeneration) return;
        emit(state.copyWith(
          isLoadingMetadata: false,
          previewMetadata: meta,
          clearError: true,
        ));
      } else {
        final meta = await _genericExtractor.fetchMetadata(url);
        if (isClosed || emit.isDone || generation != _analysisGeneration) return;
        emit(state.copyWith(
          isLoadingMetadata: false,
          previewMetadata: meta,
        ));
      }
    } catch (e) {
      if (isClosed || emit.isDone || generation != _analysisGeneration) return;
      final raw = e.toString().replaceFirst("Exception: ", "").trim();
      final lower = raw.toLowerCase();
      final errorMsg = (lower.contains("comprueba tus datos móviles") ||
              lower.contains("conexión a internet") ||
              lower.contains("failed host lookup") ||
              lower.contains("socket") ||
              lower.contains("network") ||
              lower.contains("errno = 7"))
          ? "Error de red: Comprueba tus datos móviles o Wi-Fi"
          : (lower.contains("restricciones de edad") ||
                  lower.contains("bloqueado por youtube") ||
                  lower.contains("unplayable") ||
                  lower.contains("transientfailure"))
              ? "El video tiene restricciones de edad o está bloqueado por YouTube"
              : raw;
      emit(state.copyWith(
        isLoadingMetadata: false,
        clearMetadata: true,
        metadataError: errorMsg,
      ));
    }
  }

  void _onClearMetadata(
    ClearMetadataEvent event,
    Emitter<DownloadState> emit,
  ) {
    _analysisGeneration++;
    emit(state.copyWith(
      clearMetadata: true,
      clearError: true,
      isLoadingMetadata: false,
    ));
  }

  Future<void> _onEnqueueDownload(
    EnqueueDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    await _permissionService.requestStoragePermission();
    await _permissionService.requestNotificationPermission();

    final taskId = _uuid.v4();
    final notifId = taskId.hashCode.abs() % 100000;

    String audioExt = 'mp3';
    try {
      audioExt = SettingsService.instance.getAudioFormat().name;
    } catch (_) {}

    final extension = event.fileExtension ??
        (event.mediaType == MediaType.audio ? audioExt : 'mp4');
    final title =
        event.metadata?.title ?? 'Descarga_${DateTime.now().millisecondsSinceEpoch}';

    final initialTotalBytes = event.estimatedTotalBytes ??
        (event.mediaType == MediaType.audio
            ? (event.metadata?.audioSizeBytes ?? 0)
            : (event.metadata?.videoSizeBytes ?? 0));

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
      videoItag: event.videoItag,
      audioItag: event.audioItag,
      audioLanguage: event.audioLanguage,
      specSummary: event.specSummary,
      totalBytes: initialTotalBytes,
      createdAt: DateTime.now(),
      status: DownloadStatus.queued,
    );

    if (_useForegroundIsolate) {
      await _backgroundService.enqueueTask(task);
      final updatedList = [...state.tasks, task];
      emit(state.copyWith(tasks: updatedList, clearMetadata: true));
    } else {
      _queueManager.addTask(task);
      emit(state.copyWith(clearMetadata: true));
    }
  }

  Future<void> _onPauseDownload(
    PauseDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    if (_useForegroundIsolate) {
      await _backgroundService.pauseTask(event.taskId);
      await _reloadIfIdle(emit);
    } else {
      await _queueManager.pauseTask(event.taskId);
    }
  }

  Future<void> _onResumeDownload(
    ResumeDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    if (_useForegroundIsolate) {
      await _backgroundService.resumeTask(event.taskId);
      await _reloadIfIdle(emit);
    } else {
      _queueManager.resumeTask(event.taskId);
    }
  }

  Future<void> _onCancelDownload(
    CancelDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    if (_useForegroundIsolate) {
      await _backgroundService.cancelTask(event.taskId);
      await _reloadIfIdle(emit);
    } else {
      await _queueManager.cancelTask(event.taskId);
    }
  }

  Future<void> _onRetryDownload(
    RetryDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    if (_useForegroundIsolate) {
      await _backgroundService.retryTask(event.taskId);
      await _reloadIfIdle(emit);
    } else {
      _queueManager.retryTask(event.taskId);
    }
  }

  Future<void> _onRemoveTask(
    RemoveTaskEvent event,
    Emitter<DownloadState> emit,
  ) async {
    if (_useForegroundIsolate) {
      await _backgroundService.removeTask(
        event.taskId,
        deletePhysicalFile: event.deletePhysicalFile,
      );
      await _reloadIfIdle(emit);
    } else {
      await _queueManager.removeTask(
        event.taskId,
        deletePhysicalFile: event.deletePhysicalFile,
      );
    }
  }

  Future<void> _onClearCompleted(
    ClearCompletedEvent event,
    Emitter<DownloadState> emit,
  ) async {
    if (_useForegroundIsolate) {
      await _backgroundService.clearCompleted();
      await _reloadIfIdle(emit);
    } else {
      _queueManager.clearCompleted();
    }
  }

  Future<void> _onUpdateConcurrencyLimit(
    UpdateConcurrencyLimitEvent event,
    Emitter<DownloadState> emit,
  ) async {
    try {
      await SettingsService.instance.setMaxConcurrentDownloads(event.limit);
    } catch (_) {}

    if (_useForegroundIsolate) {
      await _backgroundService.updateConcurrency(event.limit);
    } else {
      _queueManager.setMaxConcurrency(event.limit);
    }
    emit(state.copyWith(concurrencyLimit: event.limit));
  }

  Future<void> _reloadIfIdle(Emitter<DownloadState> emit) async {
    if (!await FlutterForegroundTask.isRunningService) {
      final tasks = await TaskPersistenceService.instance.loadTasks();
      emit(state.copyWith(tasks: tasks));
    }
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
    if (_taskDataCallbackAttached) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveForegroundData);
    }
    return super.close();
  }
}
