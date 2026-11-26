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
  String? muxedTempPath;
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
      if (execution.muxedTempPath != null) {
        await _safeDeleteFile(File(execution.muxedTempPath!));
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
    File? muxedTempFile;

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
      late Stream<List<int>> primaryStream;
      Stream<List<int>>? secondaryAudioStream;
      int totalBytes = task.totalBytes;
      int containerTotalBytes = task.totalBytes;
      String effectiveExtension = task.fileExtension.isNotEmpty
          ? task.fileExtension
          : (task.mediaType == MediaType.audio ? audioExtPref : 'mp4');
      bool requiresAudioExtraction = false;
      bool requiresVideoAudioMux = false;

      Future<void> bindYoutubeResolution({
        required bool forceMuxedFallback,
      }) async {
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
          forceMuxedFallback: forceMuxedFallback,
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
      }

      if (YoutubeExtractor.isYoutubeUrl(task.url)) {
        await bindYoutubeResolution(forceMuxedFallback: false);
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
      late String finalPath;

      Future<void> prepareTargetFiles() async {
        final finalFileName = '$sanitizedTitle.$effectiveExtension';
        finalPath = await _storageService.getTargetPath(
          finalFileName,
          mediaType: task.mediaType,
          duplicatePolicy: duplicatePolicy,
        );
        final tempPath = await _storageService.getTempDownloadPath(
          task.id,
          suffix: requiresVideoAudioMux ? 'video' : null,
        );
        execution.tempPath = tempPath;

        final localTemp = File(tempPath);
        tempFile = localTemp;
        await _safeDeleteFile(localTemp);

        if (requiresVideoAudioMux) {
          final audioTmpPath = await _storageService.getTempDownloadPath(
            task.id,
            suffix: 'audio',
          );
          execution.secondaryTempPath = audioTmpPath;
          final localAudioTemp = File(audioTmpPath);
          secondaryAudioTempFile = localAudioTemp;
          await _safeDeleteFile(localAudioTemp);
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
      }

      await prepareTargetFiles();

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
        bool firstChunkEmitted = false;
        double currentSpeed = 0.0;

        try {
          await for (final chunk in source.timeout(const Duration(seconds: 35))) {
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
            } else if (physicalDenominator > 0 && virtualTotal > 0) {
              final ratio = (downloadedBytes / physicalDenominator).clamp(0.0, 1.0);
              reportedDownloaded = (ratio * virtualTotal).round();
            } else {
              reportedDownloaded = downloadedBytes;
            }
            cumulativeDownloaded = reportedDownloaded;

            if (!firstChunkEmitted ||
                now.difference(lastNotificationUpdate).inMilliseconds >= 350) {
              firstChunkEmitted = true;
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
        } finally {
          try {
            await fileSink.flush();
          } catch (_) {}
          try {
            await fileSink.close();
          } catch (_) {}
          if (identical(sink, fileSink)) sink = null;
          if (identical(execution.sink, fileSink)) execution.sink = null;
        }

        if (!execution.isCanceled && !execution.isPaused && downloadedBytes <= 0) {
          throw Exception('Stream finalizado sin recibir datos (0 bytes)');
        }
        return downloadedBytes;
      }

      if (requiresVideoAudioMux &&
          secondaryAudioStream != null &&
          secondaryAudioTempFile != null) {
        final downloadedVideoBytes = await pipeToFile(
          primaryStream,
          tempFile!,
          virtualTotal: totalBytes,
          physicalDenominator: containerTotalBytes,
          baseOffset: 0,
        );
        if (execution.isCanceled || execution.isPaused) return;

        await pipeToFile(
          secondaryAudioStream!,
          secondaryAudioTempFile!,
          virtualTotal: totalBytes,
          physicalDenominator: totalBytes,
          baseOffset: downloadedVideoBytes,
        );
        if (execution.isCanceled || execution.isPaused) return;
      } else {
        try {
          await pipeToFile(
            primaryStream,
            tempFile!,
            virtualTotal: totalBytes,
            physicalDenominator: containerTotalBytes,
            baseOffset: 0,
          );
        } catch (e) {
          if (execution.isCanceled || execution.isPaused) return;
          final canRetryAudioWithMuxed = YoutubeExtractor.isYoutubeUrl(task.url) &&
              task.mediaType == MediaType.audio &&
              !requiresAudioExtraction;
          if (!canRetryAudioWithMuxed) rethrow;

          await _safeDeleteFile(tempFile!);
          await bindYoutubeResolution(forceMuxedFallback: true);
          await prepareTargetFiles();
          await pipeToFile(
            primaryStream,
            tempFile!,
            virtualTotal: totalBytes,
            physicalDenominator: containerTotalBytes,
            baseOffset: 0,
          );
        }
        if (execution.isCanceled || execution.isPaused) return;
      }

      // 4. Finalize: cache-first mux/extraction, then move or save via MediaStore
      final mimeType = switch (effectiveExtension.toLowerCase()) {
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        'webm' =>
          task.mediaType == MediaType.audio ? 'audio/webm' : 'video/webm',
        'mp4' => 'video/mp4',
        _ => 'application/octet-stream',
      };

      late String resolvedSavedPath;
      late int actualFinalBytes;
      bool savedViaMediaStore = false;

      if (requiresVideoAudioMux &&
          secondaryAudioTempFile != null &&
          await tempFile!.exists() &&
          await secondaryAudioTempFile!.exists()) {
        if (Platform.isAndroid) {
          _notificationService.showProgressNotification(
            id: task.notificationId,
            title: task.title,
            progress: 99,
            subText: 'Combinando video y audio...',
          );
          final muxedPath = await _storageService.getTempDownloadPath(
            task.id,
            suffix: 'muxed.$effectiveExtension',
          );
          execution.muxedTempPath = muxedPath;
          final muxedOut = File(muxedPath);
          muxedTempFile = muxedOut;
          await _safeDeleteFile(muxedOut);

          final muxed = await AudioExtractorService.muxVideoAndAudio(
            videoPath: tempFile!.path,
            audioPath: secondaryAudioTempFile!.path,
            outputPath: muxedPath,
            containerFormat: effectiveExtension,
          );
          if (!muxed ||
              !await muxedOut.exists() ||
              await muxedOut.length() <= 0) {
            throw Exception(
              'No se pudo combinar video y audio en ${effectiveExtension.toUpperCase()}',
            );
          }

          final saved = await _saveFinalFile(
            muxedOut,
            finalPath: finalPath,
            mediaType: task.mediaType,
            mimeType: mimeType,
          );
          resolvedSavedPath = saved.savedPath;
          actualFinalBytes = saved.fileSize;
          savedViaMediaStore = saved.savedViaMediaStore;

          await _safeDeleteFile(tempFile!);
          await _safeDeleteFile(secondaryAudioTempFile!);
        } else {
          final saved = await _saveFinalFile(
            tempFile!,
            finalPath: finalPath,
            mediaType: task.mediaType,
            mimeType: mimeType,
          );
          resolvedSavedPath = saved.savedPath;
          actualFinalBytes = saved.fileSize;
          savedViaMediaStore = saved.savedViaMediaStore;
          await _safeDeleteFile(secondaryAudioTempFile!);
        }
      } else if (await tempFile!.exists()) {
        if (requiresAudioExtraction && Platform.isAndroid) {
          _notificationService.showProgressNotification(
            id: task.notificationId,
            title: task.title,
            progress: 99,
            subText: 'Extrayendo pista de audio...',
          );
          final extractedPath = await _storageService.getTempDownloadPath(
            task.id,
            suffix: 'extracted.$effectiveExtension',
          );
          execution.muxedTempPath = extractedPath;
          final extractedOut = File(extractedPath);
          muxedTempFile = extractedOut;
          await _safeDeleteFile(extractedOut);

          final extracted = await AudioExtractorService.extractAudio(
            inputPath: tempFile!.path,
            outputPath: extractedPath,
          );
          final File sourceToSave;
          if (extracted &&
              await extractedOut.exists() &&
              await extractedOut.length() > 0) {
            sourceToSave = extractedOut;
          } else {
            sourceToSave = tempFile!;
          }

          final saved = await _saveFinalFile(
            sourceToSave,
            finalPath: finalPath,
            mediaType: task.mediaType,
            mimeType: mimeType,
          );
          resolvedSavedPath = saved.savedPath;
          actualFinalBytes = saved.fileSize;
          savedViaMediaStore = saved.savedViaMediaStore;
          await _safeDeleteFile(tempFile!);
          await _safeDeleteFile(extractedOut);
        } else {
          final saved = await _saveFinalFile(
            tempFile!,
            finalPath: finalPath,
            mediaType: task.mediaType,
            mimeType: mimeType,
          );
          resolvedSavedPath = saved.savedPath;
          actualFinalBytes = saved.fileSize;
          savedViaMediaStore = saved.savedViaMediaStore;
        }
      } else {
        throw Exception('No se encontró el archivo descargado temporal');
      }

      // 5. Notify Android MediaScanner when saved directly via filesystem
      if (scanMedia && Platform.isAndroid && !savedViaMediaStore) {
        await NativePlatformService.instance.scanMediaFile(
          resolvedSavedPath,
          mimeType: mimeType,
        );
      }

      // 6. Mark as completed
      if (actualFinalBytes <= 0) {
        actualFinalBytes = cumulativeDownloaded;
      }

      final completedIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (completedIndex >= 0) {
        _tasks[completedIndex] = _tasks[completedIndex].copyWith(
          status: DownloadStatus.completed,
          downloadedBytes: actualFinalBytes,
          totalBytes: actualFinalBytes,
          speedBytesPerSec: 0.0,
          completedAt: DateTime.now(),
          savedPath: resolvedSavedPath,
        );
        _notifyListeners();
      }

      _runningTasks.remove(task.id);

      await _notificationService.showCompletedNotification(
        id: task.notificationId,
        title: task.title,
        filePath: resolvedSavedPath,
      );

      _processQueue();
    } catch (e) {
      if (execution.isCanceled || execution.isPaused) return;

      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}

      if (tempFile != null) {
        await _safeDeleteFile(tempFile!);
      }
      if (secondaryAudioTempFile != null) {
        await _safeDeleteFile(secondaryAudioTempFile!);
      }
      if (muxedTempFile != null) {
        await _safeDeleteFile(muxedTempFile);
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

  /// Saves a finished temporary file to its destination, falling back to Android MediaStore
  /// if direct Scoped Storage filesystem writes fail.
  Future<({String savedPath, int fileSize, bool savedViaMediaStore})>
      _saveFinalFile(
    File source, {
    required String finalPath,
    required MediaType mediaType,
    required String mimeType,
  }) async {
    final sourceBytes = await source.length();
    if (sourceBytes <= 0) {
      throw Exception('El archivo final está vacío (0 bytes)');
    }

    final destFile = File(finalPath);
    try {
      if (await destFile.exists()) {
        await _safeDeleteFile(destFile);
      }
      await _moveFileSafely(source, finalPath);
      final movedSize =
          await destFile.exists() ? await destFile.length() : sourceBytes;
      return (
        savedPath: finalPath,
        fileSize: movedSize,
        savedViaMediaStore: false,
      );
    } on FileSystemException {
      if (!Platform.isAndroid) rethrow;
      final fileName = destFile.uri.pathSegments.isNotEmpty
          ? destFile.uri.pathSegments.last
          : finalPath.split(RegExp(r'[/\\]')).last;
      final relSubdir = _extractAndroidRelativeSubdir(destFile.parent.path);
      final mediaStorePath =
          await NativePlatformService.instance.saveToMediaStore(
        sourcePath: source.path,
        fileName: fileName,
        mediaType: mediaType == MediaType.audio ? 'audio' : 'video',
        relativeSubdir: relSubdir,
        mimeType: mimeType,
      );
      if (mediaStorePath == null || mediaStorePath.isEmpty) {
        rethrow;
      }
      await _safeDeleteFile(source);
      return (
        savedPath: mediaStorePath,
        fileSize: sourceBytes,
        savedViaMediaStore: true,
      );
    }
  }

  String? _extractAndroidRelativeSubdir(String parentPath) {
    final normalized = parentPath.replaceAll('\\', '/');
    const markers = ['/storage/emulated/0/', '/sdcard/'];
    for (final marker in markers) {
      final idx = normalized.indexOf(marker);
      if (idx >= 0) {
        final sub = normalized.substring(idx + marker.length).trim();
        return sub.isEmpty ? null : sub;
      }
    }
    return null;
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
