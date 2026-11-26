import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:medias_download/core/constants/app_constants.dart';
import 'package:medias_download/core/services/audio_extractor_service.dart';
import 'package:medias_download/core/services/background_service.dart';
import 'package:medias_download/core/services/native_platform_service.dart';
import 'package:medias_download/core/services/notification_service.dart';
import 'package:medias_download/core/services/settings_service.dart';
import 'package:medias_download/core/services/storage_service.dart';
import 'package:medias_download/core/utils/formatters.dart';
import 'package:medias_download/features/downloader/data/datasources/generic_extractor.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';

class _ActiveTaskExecution {
  StreamSubscription? subscription;
  IOSink? sink;
  http.Client? httpClient;
  String? tempPath;
  String? secondaryTempPath;
  bool isCanceled = false;
  bool isPaused = false;
}

class DownloadQueueManager {
  static DownloadQueueManager? _instance;
  static DownloadQueueManager get instance => _instance ??= DownloadQueueManager._();

  /// Dedicated instance constructor for isolated background execution (`TaskHandler`).
  factory DownloadQueueManager.isolated({
    YoutubeExtractor? youtubeExtractor,
    GenericExtractor? genericExtractor,
    StorageService? storageService,
    NotificationService? notificationService,
    BackgroundService? backgroundService,
    bool manageForegroundService = false,
  }) {
    return DownloadQueueManager._(
      youtubeExtractor: youtubeExtractor,
      genericExtractor: genericExtractor,
      storageService: storageService,
      notificationService: notificationService,
      backgroundService: backgroundService,
      manageForegroundService: manageForegroundService,
    );
  }

  final YoutubeExtractor _youtubeExtractor;
  final GenericExtractor _genericExtractor;
  final StorageService _storageService;
  final NotificationService _notificationService;
  final BackgroundService _backgroundService;
  final bool manageForegroundService;

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
    this.manageForegroundService = true,
  })  : _youtubeExtractor = youtubeExtractor ?? YoutubeExtractor(),
        _genericExtractor = genericExtractor ?? GenericExtractor(),
        _storageService = storageService ?? StorageService.instance,
        _notificationService = notificationService ?? NotificationService.instance,
        _backgroundService = backgroundService ?? BackgroundService.instance;

  Stream<List<DownloadTask>> get tasksStream => _tasksController.stream;
  List<DownloadTask> get currentTasks => List.unmodifiable(_tasks);
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  void setMaxConcurrency(int limit) {
    final clamped = limit.clamp(1, 4);
    if (clamped != _maxConcurrentDownloads) {
      _maxConcurrentDownloads = clamped;
      _processQueue();
    }
  }

  /// Seed tasks from persistence before starting queue processing.
  void seedTasks(List<DownloadTask> initialTasks) {
    for (final task in initialTasks) {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx >= 0) {
        _tasks[idx] = task;
      } else {
        _tasks.add(task);
      }
    }
    _notifyListeners();
    _processQueue();
  }

  /// Add a new task to queue
  void addTask(DownloadTask task) {
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
      _processQueue();
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
        clearErrorMessage: true,
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
      if (execution.tempPath != null) {
        await _safeDeleteFile(File(execution.tempPath!));
      }
      if (execution.secondaryTempPath != null) {
        await _safeDeleteFile(File(execution.secondaryTempPath!));
      }
      _runningTasks.remove(taskId);
    }

    await _notificationService.cancelNotification(task.notificationId);

    if (task.savedPath != null) {
      await _safeDeleteFile(File('${task.savedPath}.tmp'));
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
      clearErrorMessage: true,
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
      await _safeDeleteFile(File('${task.savedPath}.tmp'));
    }

    _tasks.removeWhere((t) => t.id == taskId);
    _notifyListeners();
    _processQueue();
  }

  /// Clear all completed or canceled tasks from the list
  void clearCompleted() {
    _tasks.removeWhere((t) => t.isTerminal && t.status != DownloadStatus.failed);
    _notifyListeners();
  }

  /// Main queue processor with concurrency throttling
  void _processQueue() {
    final activeCount =
        _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    if (activeCount >= _maxConcurrentDownloads) return;

    final slotsAvailable = _maxConcurrentDownloads - activeCount;
    final queuedTasks = _tasks
        .where((t) => t.status == DownloadStatus.queued)
        .take(slotsAvailable)
        .toList();

    if (queuedTasks.isEmpty && activeCount == 0) {
      if (manageForegroundService) {
        _backgroundService.stopService();
      }
      return;
    }

    if (manageForegroundService &&
        (activeCount > 0 || queuedTasks.isNotEmpty)) {
      _backgroundService.startService(
        statusText:
            'Descargas activas: $activeCount | En espera: ${_tasks.where((t) => t.status == DownloadStatus.queued).length}',
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

    _tasks[taskIndex] = task.copyWith(
      status: DownloadStatus.downloading,
      clearErrorMessage: true,
    );
    _notifyListeners();

    final execution = _ActiveTaskExecution();
    _runningTasks[task.id] = execution;

    IOSink? sink;
    File? tempFile;
    File? secondaryAudioTempFile;
    File? finalFile;

    try {
      // Safe settings load (no-op if SettingsService not initialized in pure Dart unit tests)
      final settingsReady = await _ensureSettingsSafe();
      final wifiOnly =
          settingsReady ? SettingsService.instance.getWifiOnly() : false;
      final audioExtPref = settingsReady
          ? SettingsService.instance.getAudioFormat().name
          : 'mp3';
      final videoFormatPref = settingsReady
          ? SettingsService.instance.getDefaultVideoFormat()
          : VideoFormatPreference.auto;
      final includeAuthor = settingsReady
          ? SettingsService.instance.getIncludeAuthorInFilename()
          : false;
      final duplicatePolicy = settingsReady
          ? SettingsService.instance.getDuplicatePolicy()
          : DuplicateFilePolicy.rename;
      final scanMedia = settingsReady
          ? SettingsService.instance.getScanMediaLibrary()
          : true;

      // Enforce Wi-Fi only preference on Android
      if (wifiOnly && Platform.isAndroid) {
        final onWifi = await NativePlatformService.instance.isWifiConnected();
        if (!onWifi) {
          _runningTasks.remove(task.id);
          final idx = _tasks.indexWhere((t) => t.id == task.id);
          if (idx >= 0) {
            _tasks[idx] = _tasks[idx].copyWith(
              status: DownloadStatus.paused,
              speedBytesPerSec: 0.0,
              errorMessage: 'En pausa: esperando conexión Wi-Fi',
            );
            _notifyListeners();
          }
          _processQueue();
          return;
        }
      }

      // 1. Resolve Stream(s)
      Stream<List<int>> primaryStream;
      Stream<List<int>>? secondaryAudioStream;
      int totalBytes = task.totalBytes;
      int containerTotalBytes = task.totalBytes;
      String effectiveExtension = task.fileExtension.isNotEmpty
          ? task.fileExtension
          : (task.mediaType == MediaType.audio ? audioExtPref : 'mp4');
      bool requiresAudioExtraction = false;
      bool requiresVideoAudioMux = false;

      if (YoutubeExtractor.isYoutubeUrl(task.url)) {
        final targetAudioExt = task.mediaType == MediaType.audio
            ? (task.fileExtension.isNotEmpty ? task.fileExtension : audioExtPref)
            : audioExtPref;
        final resolved = await _youtubeExtractor.resolveStream(
          url: task.url,
          mediaType: task.mediaType,
          quality: task.quality,
          audioExtension: targetAudioExt,
          preferredVideoFormat: videoFormatPref,
          videoItag: task.videoItag,
          audioItag: task.audioItag,
          audioLanguage: task.audioLanguage,
        );
        primaryStream = resolved.stream;
        secondaryAudioStream = resolved.secondaryAudioStream;
        totalBytes = resolved.totalBytes;
        containerTotalBytes = resolved.containerTotalBytes;
        requiresAudioExtraction = resolved.requiresAudioExtraction;
        requiresVideoAudioMux = resolved.isDualAdaptive;
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
        execution.httpClient = httpClient;
        final request = http.Request('GET', Uri.parse(genericResult.streamUrl));
        final response = await httpClient.send(request);
        primaryStream = response.stream;
      }

      // 2. Prepare target file paths (separate Audio/Video directories & temp in cache)
      final baseTitle = _buildFileBaseName(
        title: task.title,
        author: task.author,
        includeAuthor: includeAuthor,
      );
      final sanitizedTitle = Formatters.sanitizeFileName(baseTitle);
      final finalFileName = '$sanitizedTitle.$effectiveExtension';
      final finalPath = await _storageService.getTargetPath(
        finalFileName,
        mediaType: task.mediaType,
        duplicatePolicy: duplicatePolicy,
      );
      final tempPath = await _storageService.getTempDownloadPath(
        task.id,
        suffix: requiresVideoAudioMux ? 'video' : null,
      );
      execution.tempPath = tempPath;

      finalFile = File(finalPath);
      tempFile = File(tempPath);
      await _safeDeleteFile(tempFile);

      if (requiresVideoAudioMux) {
        final audioTmpPath = await _storageService.getTempDownloadPath(
          task.id,
          suffix: 'audio',
        );
        execution.secondaryTempPath = audioTmpPath;
        secondaryAudioTempFile = File(audioTmpPath);
        await _safeDeleteFile(secondaryAudioTempFile);
      }

      // Update total bytes and resolved path
      final currentIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (currentIndex >= 0) {
        _tasks[currentIndex] = _tasks[currentIndex].copyWith(
          totalBytes: totalBytes,
          fileExtension: effectiveExtension,
          savedPath: finalPath,
        );
        _notifyListeners();
      }

      // 3. Pipe stream(s) into temp file(s) with unified progress & speed calculation
      int cumulativeDownloaded = 0;

      Future<int> pipeToFile(
        Stream<List<int>> source,
        File target, {
        required int virtualTotal,
        required int physicalDenominator,
        required int baseOffset,
      }) async {
        final fileSink = target.openWrite(mode: FileMode.writeOnly);
        sink = fileSink;
        execution.sink = fileSink;

        int downloadedBytes = 0;
        int lastBytes = 0;
        DateTime lastSpeedCheck = DateTime.now();
        DateTime lastNotificationUpdate = DateTime.now();
        double currentSpeed = 0.0;

        await for (final chunk in source) {
          if (execution.isCanceled || execution.isPaused) break;

          fileSink.add(chunk);
          downloadedBytes += chunk.length;

          final now = DateTime.now();
          final speedInterval = now.difference(lastSpeedCheck).inMilliseconds;
          if (speedInterval >= 1000) {
            final bytesDiff = downloadedBytes - lastBytes;
            final physicalSpeed = bytesDiff / (speedInterval / 1000);
            currentSpeed = (physicalDenominator > 0 &&
                    virtualTotal != physicalDenominator &&
                    !requiresVideoAudioMux)
                ? physicalSpeed * (virtualTotal / physicalDenominator)
                : physicalSpeed;
            lastBytes = downloadedBytes;
            lastSpeedCheck = now;
          }

          final int reportedDownloaded;
          if (requiresVideoAudioMux) {
            reportedDownloaded = baseOffset + downloadedBytes;
          } else {
            final ratio = physicalDenominator > 0
                ? (downloadedBytes / physicalDenominator).clamp(0.0, 1.0)
                : 0.0;
            reportedDownloaded = (ratio * virtualTotal).round();
          }
          cumulativeDownloaded = reportedDownloaded;

          if (now.difference(lastNotificationUpdate).inMilliseconds >= 350) {
            lastNotificationUpdate = now;
            final idx = _tasks.indexWhere((t) => t.id == task.id);
            if (idx >= 0) {
              _tasks[idx] = _tasks[idx].copyWith(
                downloadedBytes: reportedDownloaded,
                speedBytesPerSec: currentSpeed,
              );
              _notifyListeners();

              final percent = _tasks[idx].progressPercent;
              final speedLabel = Formatters.formatSpeed(currentSpeed);
              final dlLabel = Formatters.formatBytes(reportedDownloaded);
              final totLabel =
                  totalBytes > 0 ? Formatters.formatBytes(totalBytes) : '...';

              _notificationService.showProgressNotification(
                id: task.notificationId,
                title: task.title,
                progress: percent,
                subText: '$percent% ($dlLabel / $totLabel) • $speedLabel',
              );
            }
          }
        }

        await fileSink.flush();
        await fileSink.close();
        sink = null;
        execution.sink = null;
        return downloadedBytes;
      }

      if (requiresVideoAudioMux && secondaryAudioStream != null && secondaryAudioTempFile != null) {
        final downloadedVideoBytes = await pipeToFile(
          primaryStream,
          tempFile,
          virtualTotal: totalBytes,
          physicalDenominator: containerTotalBytes,
          baseOffset: 0,
        );
        if (execution.isCanceled || execution.isPaused) return;

        await pipeToFile(
          secondaryAudioStream,
          secondaryAudioTempFile,
          virtualTotal: totalBytes,
          physicalDenominator: totalBytes,
          baseOffset: downloadedVideoBytes,
        );
        if (execution.isCanceled || execution.isPaused) return;
      } else {
        await pipeToFile(
          primaryStream,
          tempFile,
          virtualTotal: totalBytes,
          physicalDenominator: containerTotalBytes,
          baseOffset: 0,
        );
        if (execution.isCanceled || execution.isPaused) return;
      }

      // 4. Finalize: dual mux OR audio extraction OR move
      if (requiresVideoAudioMux &&
          secondaryAudioTempFile != null &&
          await tempFile.exists() &&
          await secondaryAudioTempFile.exists()) {
        if (Platform.isAndroid) {
          _notificationService.showProgressNotification(
            id: task.notificationId,
            title: task.title,
            progress: 99,
            subText: 'Combinando video y audio...',
          );
          final muxed = await AudioExtractorService.muxVideoAndAudio(
            videoPath: tempPath,
            audioPath: secondaryAudioTempFile.path,
            outputPath: finalPath,
            containerFormat: effectiveExtension,
          );
          if (!muxed) {
            throw Exception(
              'No se pudo combinar video y audio en ${effectiveExtension.toUpperCase()}',
            );
          }
          await _safeDeleteFile(tempFile);
          await _safeDeleteFile(secondaryAudioTempFile);
        } else {
          await _moveFileSafely(tempFile, finalPath);
          await _safeDeleteFile(secondaryAudioTempFile);
        }
      } else if (await tempFile.exists()) {
        if (requiresAudioExtraction && Platform.isAndroid) {
          final extracted = await AudioExtractorService.extractAudio(
            inputPath: tempPath,
            outputPath: finalPath,
          );
          if (!extracted) {
            await _moveFileSafely(tempFile, finalPath);
          } else {
            await _safeDeleteFile(tempFile);
          }
        } else {
          if (await finalFile.exists()) {
            await _safeDeleteFile(finalFile);
          }
          await _moveFileSafely(tempFile, finalPath);
        }
      }

      // 5. Notify Android MediaScanner so music players & galleries index the file
      if (scanMedia && Platform.isAndroid) {
        final mimeType = switch (effectiveExtension.toLowerCase()) {
          'mp3' => 'audio/mpeg',
          'm4a' => 'audio/mp4',
          'webm' =>
            task.mediaType == MediaType.audio ? 'audio/webm' : 'video/webm',
          'mp4' => 'video/mp4',
          _ => null,
        };
        await NativePlatformService.instance.scanMediaFile(
          finalPath,
          mimeType: mimeType,
        );
      }

      // 6. Mark as completed
      final actualFinalBytes = (await finalFile.exists())
          ? await finalFile.length()
          : cumulativeDownloaded;

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

      await _notificationService.showCompletedNotification(
        id: task.notificationId,
        title: task.title,
        filePath: finalPath,
      );

      _processQueue();
    } catch (e) {
      if (execution.isCanceled || execution.isPaused) return;

      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}

      if (tempFile != null) {
        await _safeDeleteFile(tempFile);
      }
      if (secondaryAudioTempFile != null) {
        await _safeDeleteFile(secondaryAudioTempFile);
      }

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

      _processQueue();
    }
  }

  Future<bool> _ensureSettingsSafe() async {
    try {
      await SettingsService.instance.reload();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _buildFileBaseName({
    required String title,
    required String? author,
    required bool includeAuthor,
  }) {
    if (!includeAuthor || author == null) return title;
    final cleanAuthor = author.trim();
    if (cleanAuthor.isEmpty ||
        cleanAuthor == 'YouTube' ||
        cleanAuthor == 'Web Directo') {
      return title;
    }
    if (title.toLowerCase().contains(cleanAuthor.toLowerCase())) {
      return title;
    }
    return '$cleanAuthor - $title';
  }

  /// Moves a file safely across mount points (falls back to copy+delete on EXDEV).
  Future<void> _moveFileSafely(File source, String destinationPath) async {
    final destFile = File(destinationPath);
    if (destFile.parent != source.parent && !await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }
    try {
      await source.rename(destinationPath);
    } on FileSystemException {
      await source.copy(destinationPath);
      await _safeDeleteFile(source);
    }
  }

  Future<void> _safeDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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
    _genericExtractor.close();
  }
}
