import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:medias_download/core/constants/app_constants.dart';
import 'package:medias_download/core/services/background_service.dart';
import 'package:medias_download/core/services/notification_service.dart';
import 'package:medias_download/core/services/storage_service.dart';
import 'package:medias_download/core/utils/formatters.dart';
import 'package:medias_download/core/services/audio_extractor_service.dart';
import 'package:medias_download/features/downloader/data/datasources/generic_extractor.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';

class _ActiveTaskExecution {
  StreamSubscription? subscription;
  IOSink? sink;
  http.Client? httpClient;
  bool isCanceled = false;
  bool isPaused = false;
}

class DownloadQueueManager {
  static DownloadQueueManager? _instance;
  static DownloadQueueManager get instance => _instance ??= DownloadQueueManager._();

  final YoutubeExtractor _youtubeExtractor;
  final GenericExtractor _genericExtractor;
  final StorageService _storageService;
  final NotificationService _notificationService;
  final BackgroundService _backgroundService;

  int _maxConcurrentDownloads = AppConstants.defaultMaxConcurrentDownloads;
  final List<DownloadTask> _tasks = [];
  final Map<String, _ActiveTaskExecution> _runningTasks = {};

  final StreamController<List<DownloadTask>> _tasksController =
      StreamController<List<DownloadTask>>.broadcast();

  DownloadQueueManager._({
    YoutubeExtractor? youtubeExtractor,
    GenericExtractor? genericExtractor,
    StorageService? storageService,
    NotificationService? notificationService,
    BackgroundService? backgroundService,
  })  : _youtubeExtractor = youtubeExtractor ?? YoutubeExtractor(),
        _genericExtractor = genericExtractor ?? GenericExtractor(),
        _storageService = storageService ?? StorageService.instance,
        _notificationService = notificationService ?? NotificationService.instance,
        _backgroundService = backgroundService ?? BackgroundService.instance;

  Stream<List<DownloadTask>> get tasksStream => _tasksController.stream;
  List<DownloadTask> get currentTasks => List.unmodifiable(_tasks);
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  void setMaxConcurrency(int limit) {
    if (limit > 0 && limit != _maxConcurrentDownloads) {
      _maxConcurrentDownloads = limit;
      _processQueue();
    }
  }

  /// Add a new task to queue
  void addTask(DownloadTask task) {
    // Avoid duplicate tasks in active/queued list
    final existingIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (existingIndex >= 0) {
      _tasks[existingIndex] = task;
    } else {
      _tasks.add(task);
    }
    _notifyListeners();
    _processQueue();
  }

  /// Pause an active or queued download
  Future<void> pauseTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.status == DownloadStatus.queued) {
      _tasks[index] = task.copyWith(status: DownloadStatus.paused);
      _notifyListeners();
      return;
    }

    if (task.status == DownloadStatus.downloading) {
      final execution = _runningTasks[taskId];
      if (execution != null) {
        execution.isPaused = true;
        await execution.subscription?.cancel();
        await execution.sink?.flush();
        await execution.sink?.close();
        execution.httpClient?.close();
        _runningTasks.remove(taskId);
      }

      await _notificationService.cancelNotification(task.notificationId);
      _tasks[index] = task.copyWith(
        status: DownloadStatus.paused,
        speedBytesPerSec: 0,
      );
      _notifyListeners();
      _processQueue();
    }
  }

  /// Resume a paused task
  void resumeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.status == DownloadStatus.paused) {
      _tasks[index] = task.copyWith(
        status: DownloadStatus.queued,
        errorMessage: null,
      );
      _notifyListeners();
      _processQueue();
    }
  }

  /// Cancel a task and cleanup temporary files
  Future<void> cancelTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    final execution = _runningTasks[taskId];
    if (execution != null) {
      execution.isCanceled = true;
      await execution.subscription?.cancel();
      await execution.sink?.flush();
      await execution.sink?.close();
      execution.httpClient?.close();
      _runningTasks.remove(taskId);
    }

    await _notificationService.cancelNotification(task.notificationId);

    // Delete temp file if exists
    if (task.savedPath != null) {
      final tempFile = File('${task.savedPath}.tmp');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    _tasks[index] = task.copyWith(
      status: DownloadStatus.canceled,
      speedBytesPerSec: 0,
    );
    _notifyListeners();
    _processQueue();
  }

  /// Retry a failed or canceled task
  void retryTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    _tasks[index] = task.copyWith(
      status: DownloadStatus.queued,
      downloadedBytes: 0,
      speedBytesPerSec: 0,
      errorMessage: null,
    );
    _notifyListeners();
    _processQueue();
  }

  /// Remove task from list, with option to delete the downloaded file from disk
  Future<void> removeTask(String taskId, {bool deletePhysicalFile = false}) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isActive) {
      await cancelTask(taskId);
    }

    if (deletePhysicalFile && task.savedPath != null) {
      await _storageService.deleteFile(task.savedPath!);
      final tempFile = File('${task.savedPath}.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }

    _tasks.removeWhere((t) => t.id == taskId);
    _notifyListeners();
  }

  /// Clear all completed or canceled tasks from the list
  void clearCompleted() {
    _tasks.removeWhere((t) => t.isTerminal && t.status != DownloadStatus.failed);
    _notifyListeners();
  }

  /// Main queue processor with concurrency throttling
  void _processQueue() {
    final activeCount = _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    if (activeCount >= _maxConcurrentDownloads) return;

    final slotsAvailable = _maxConcurrentDownloads - activeCount;
    final queuedTasks = _tasks.where((t) => t.status == DownloadStatus.queued).take(slotsAvailable).toList();

    if (queuedTasks.isEmpty && activeCount == 0) {
      // All tasks finished - stop foreground service
      _backgroundService.stopService();
      return;
    }

    if (activeCount > 0 || queuedTasks.isNotEmpty) {
      _backgroundService.startService(
        statusText: 'Descargas activas: $activeCount | En espera: ${_tasks.where((t) => t.status == DownloadStatus.queued).length}',
      );
    }

    for (final task in queuedTasks) {
      _startDownload(task);
    }
  }

  /// Executes download stream with progress tracking, notification and error handling
  Future<void> _startDownload(DownloadTask task) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (taskIndex == -1) return;

    // Mark as downloading
    _tasks[taskIndex] = task.copyWith(
      status: DownloadStatus.downloading,
      errorMessage: null,
    );
    _notifyListeners();

    final execution = _ActiveTaskExecution();
    _runningTasks[task.id] = execution;

    IOSink? sink;
    File? tempFile;
    File? finalFile;

    try {
      // 1. Resolve Stream
      Stream<List<int>> stream;
      int totalBytes = task.totalBytes;
      int containerTotalBytes = task.totalBytes;
      String effectiveExtension = task.fileExtension;
      bool requiresAudioExtraction = false;

      if (YoutubeExtractor.isYoutubeUrl(task.url)) {
        final resolved = await _youtubeExtractor.resolveStream(
          url: task.url,
          mediaType: task.mediaType,
          quality: task.quality,
        );
        stream = resolved.stream;
        totalBytes = resolved.totalBytes;
        containerTotalBytes = resolved.containerTotalBytes;
        requiresAudioExtraction = resolved.requiresAudioExtraction;
        if (resolved.extension.isNotEmpty) {
          effectiveExtension = resolved.extension;
        }
      } else {
        final genericResult = await _genericExtractor.resolveStream(
          url: task.url,
          mediaType: task.mediaType,
        );
        totalBytes = genericResult.totalBytes;
        containerTotalBytes = genericResult.totalBytes;
        if (genericResult.extension.isNotEmpty) {
          effectiveExtension = genericResult.extension;
        }

        final httpClient = http.Client();
        final request = http.Request('GET', Uri.parse(genericResult.streamUrl));
        final response = await httpClient.send(request);
        stream = response.stream;
      }

      // 2. Prepare target file paths with correct extension
      final sanitizedTitle = Formatters.sanitizeFileName(task.title);
      final finalFileName = '$sanitizedTitle.$effectiveExtension';
      final finalPath = await _storageService.getTargetPath(finalFileName);
      final tempPath = '$finalPath.tmp';

      finalFile = File(finalPath);
      tempFile = File(tempPath);

      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      sink = tempFile.openWrite(mode: FileMode.writeOnly);

      // Update total bytes if known
      final currentIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (currentIndex >= 0) {
        _tasks[currentIndex] = _tasks[currentIndex].copyWith(
          totalBytes: totalBytes,
          savedPath: finalPath,
        );
        _notifyListeners();
      }

      // 3. Pipe stream into file with throttled metrics calculation
      int downloadedContainerBytes = 0;
      int virtualDownloadedBytes = 0;
      int lastDownloadedContainerBytes = 0;
      DateTime lastSpeedCheck = DateTime.now();
      DateTime lastNotificationUpdate = DateTime.now();
      double currentSpeed = 0.0;

      await for (final chunk in stream) {
        if (execution.isCanceled || execution.isPaused) {
          break;
        }

        sink.add(chunk);
        downloadedContainerBytes += chunk.length;

        final now = DateTime.now();

        // Speed calculation every 1000ms
        final speedInterval = now.difference(lastSpeedCheck).inMilliseconds;
        if (speedInterval >= 1000) {
          final bytesDiff = downloadedContainerBytes - lastDownloadedContainerBytes;
          final physicalSpeed = (bytesDiff / (speedInterval / 1000));
          currentSpeed = (containerTotalBytes > 0 && totalBytes != containerTotalBytes)
              ? physicalSpeed * (totalBytes / containerTotalBytes)
              : physicalSpeed;
          lastDownloadedContainerBytes = downloadedContainerBytes;
          lastSpeedCheck = now;
        }

        // Virtual downloaded bytes proportionally matching totalBytes
        final progressRatio = containerTotalBytes > 0
            ? (downloadedContainerBytes / containerTotalBytes).clamp(0.0, 1.0)
            : 0.0;
        virtualDownloadedBytes = (progressRatio * totalBytes).round();

        // Throttle UI and Notification updates every 400ms
        if (now.difference(lastNotificationUpdate).inMilliseconds >= 400) {
          lastNotificationUpdate = now;
          final idx = _tasks.indexWhere((t) => t.id == task.id);
          if (idx >= 0) {
            _tasks[idx] = _tasks[idx].copyWith(
              downloadedBytes: virtualDownloadedBytes,
              speedBytesPerSec: currentSpeed,
            );
            _notifyListeners();

            // Native notification update
            final percent = _tasks[idx].progressPercent;
            final speedLabel = Formatters.formatSpeed(currentSpeed);
            final downloadedLabel = Formatters.formatBytes(virtualDownloadedBytes);
            final totalLabel = totalBytes > 0 ? Formatters.formatBytes(totalBytes) : '...';

            _notificationService.showProgressNotification(
              id: task.notificationId,
              title: task.title,
              progress: percent,
              subText: '$percent% ($downloadedLabel / $totalLabel) • $speedLabel',
            );
          }
        }
      }

      await sink.flush();
      await sink.close();

      // If user paused or canceled, stop here
      if (execution.isCanceled || execution.isPaused) {
        return;
      }

      // 4. Rename temp file to final file (or extract audio if required)
      if (await tempFile.exists()) {
        if (requiresAudioExtraction && Platform.isAndroid) {
          final extracted = await AudioExtractorService.extractAudio(
            inputPath: tempPath,
            outputPath: finalPath,
          );
          try {
            await tempFile.delete();
          } catch (_) {}
          if (!extracted) {
            await tempFile.rename(finalPath);
          }
        } else {
          if (await finalFile.exists()) {
            await finalFile.delete();
          }
          await tempFile.rename(finalPath);
        }
      }

      // 5. Mark as completed
      final actualFinalBytes = (await finalFile.exists())
          ? await finalFile.length()
          : virtualDownloadedBytes;

      final completedIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (completedIndex >= 0) {
        _tasks[completedIndex] = _tasks[completedIndex].copyWith(
          status: DownloadStatus.completed,
          downloadedBytes: actualFinalBytes,
          totalBytes: actualFinalBytes,
          speedBytesPerSec: 0.0,
          completedAt: DateTime.now(),
          savedPath: finalPath,
        );
        _notifyListeners();
      }

      _runningTasks.remove(task.id);

      // 6. Show success notification
      await _notificationService.showCompletedNotification(
        id: task.notificationId,
        title: task.title,
        filePath: finalPath,
      );

      // Process next queued task
      _processQueue();
    } catch (e) {
      if (execution.isCanceled || execution.isPaused) return;

      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}

      final errIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (errIndex >= 0) {
        _tasks[errIndex] = _tasks[errIndex].copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
          speedBytesPerSec: 0.0,
        );
        _notifyListeners();
      }

      _runningTasks.remove(task.id);

      await _notificationService.showErrorNotification(
        id: task.notificationId,
        title: task.title,
        error: e.toString().replaceFirst('Exception: ', ''),
      );

      // Continue queue
      _processQueue();
    }
  }

  void _notifyListeners() {
    if (!_tasksController.isClosed) {
      _tasksController.add(List.unmodifiable(_tasks));
    }
  }

  void dispose() {
    for (final exec in _runningTasks.values) {
      exec.subscription?.cancel();
      exec.sink?.close();
      exec.httpClient?.close();
    }
    _runningTasks.clear();
    _tasksController.close();
    _youtubeExtractor.close();
  }
}

