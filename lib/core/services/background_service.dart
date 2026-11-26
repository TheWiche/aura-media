import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../features/downloader/data/models/download_task.dart';
import '../../features/downloader/domain/queue/download_queue_manager.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'task_persistence_service.dart';

/// Top-level callback invoked by Android's ForegroundService isolate.
@pragma('vm:entry-point')
void downloadTaskCallback() {
  FlutterForegroundTask.setTaskHandler(DownloadForegroundTaskHandler());
}

/// Runs inside the persistent Android ForegroundService FlutterEngine so downloads
/// survive even if `ShareModalActivity` closes immediately or `MainActivity` is closed.
class DownloadForegroundTaskHandler extends TaskHandler {
  DownloadQueueManager? _queueManager;
  StreamSubscription<List<DownloadTask>>? _sub;
  DateTime _lastPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isStopping = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    await SettingsService.instance.initialize();
    await SettingsService.instance.reload();
    await NotificationService.instance.initialize();

    final manager = DownloadQueueManager.isolated(
      manageForegroundService: false,
    );
    _queueManager = manager;
    manager.setMaxConcurrency(
      SettingsService.instance.getMaxConcurrentDownloads(),
    );

    _sub = manager.tasksStream.listen((tasks) async {
      _broadcastTasks(tasks);
      await _persistThrottled(tasks);
      await _updateNotificationOrStop(tasks);
    });

    final persisted = await TaskPersistenceService.instance.loadTasks(
      recoverInterrupted: true,
    );
    final pending =
        await TaskPersistenceService.instance.takePendingEnqueueTasks();

    final combined = <DownloadTask>[...persisted];
    for (final p in pending) {
      final idx = combined.indexWhere((t) => t.id == p.id);
      if (idx >= 0) {
        combined[idx] = p;
      } else {
        combined.add(p);
      }
    }

    manager.seedTasks(combined);
    _broadcastTasks(manager.currentTasks);
    await TaskPersistenceService.instance.saveTasks(manager.currentTasks);
    await _updateNotificationOrStop(manager.currentTasks);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {
    final manager = _queueManager;
    if (manager == null || data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final action = map['action'] as String?;

    switch (action) {
      case 'enqueue':
        final rawTask = map['task'];
        if (rawTask is Map) {
          _isStopping = false;
          final task = DownloadTask.fromJson(Map<String, dynamic>.from(rawTask));
          manager.addTask(task);
        }
        break;
      case 'pause':
        final id = map['taskId'] as String?;
        if (id != null) manager.pauseTask(id);
        break;
      case 'resume':
        final id = map['taskId'] as String?;
        if (id != null) {
          _isStopping = false;
          manager.resumeTask(id);
        }
        break;
      case 'cancel':
        final id = map['taskId'] as String?;
        if (id != null) manager.cancelTask(id);
        break;
      case 'retry':
        final id = map['taskId'] as String?;
        if (id != null) {
          _isStopping = false;
          manager.retryTask(id);
        }
        break;
      case 'remove':
        final id = map['taskId'] as String?;
        final deletePhysical = map['deletePhysicalFile'] as bool? ?? false;
        if (id != null) {
          manager.removeTask(id, deletePhysicalFile: deletePhysical);
        }
        break;
      case 'clearCompleted':
        manager.clearCompleted();
        break;
      case 'updateConcurrency':
        final limit = (map['limit'] as num?)?.toInt();
        if (limit != null) manager.setMaxConcurrency(limit);
        break;
      case 'reloadSettings':
        SettingsService.instance.reload().then((_) {
          manager.setMaxConcurrency(
            SettingsService.instance.getMaxConcurrentDownloads(),
          );
        });
        break;
      case 'sync':
        _broadcastTasks(manager.currentTasks);
        break;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    final manager = _queueManager;
    if (manager != null) {
      await TaskPersistenceService.instance.saveTasks(manager.currentTasks);
      await _sub?.cancel();
      manager.dispose();
      _queueManager = null;
    }
  }

  void _broadcastTasks(List<DownloadTask> tasks) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'tasks',
      'tasks': tasks.map((t) => t.toJson()).toList(),
    });
  }

  Future<void> _persistThrottled(List<DownloadTask> tasks) async {
    final now = DateTime.now();
    if (now.difference(_lastPersistedAt).inMilliseconds >= 1200) {
      _lastPersistedAt = now;
      await TaskPersistenceService.instance.saveTasks(tasks);
    }
  }

  Future<void> _updateNotificationOrStop(List<DownloadTask> tasks) async {
    final downloading =
        tasks.where((t) => t.status == DownloadStatus.downloading).length;
    final queued =
        tasks.where((t) => t.status == DownloadStatus.queued).length;

    if (downloading == 0 && queued == 0) {
      if (_isStopping) return;
      _isStopping = true;
      await TaskPersistenceService.instance.saveTasks(tasks);
      _broadcastTasks(tasks);
      await Future.delayed(const Duration(milliseconds: 250));
      if (!_isStopping) return;
      final current = _queueManager?.currentTasks ?? const <DownloadTask>[];
      final hasActiveOrQueued = current.any(
        (t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.queued,
      );
      if (hasActiveOrQueued) {
        _isStopping = false;
        return;
      }
      await FlutterForegroundTask.stopService();
      return;
    }

    _isStopping = false;
    await FlutterForegroundTask.updateService(
      notificationTitle: AppConstants.foregroundNotificationTitle,
      notificationText:
          'Descargas activas: $downloading · En espera: $queued',
    );
  }
}

/// Client-side coordinator used by `MainActivity` and `ShareModalActivity`.
class BackgroundService {
  static BackgroundService? _instance;
  static BackgroundService get instance => _instance ??= BackgroundService._();
  BackgroundService._();

  bool _initialized = false;

  /// Initialize foreground task settings
  void initialize() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'media_download_fg_service',
        channelName: 'Servicio de Descarga en Segundo Plano',
        channelDescription: 'Mantiene las descargas activas en segundo plano',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
  }

  /// Starts the foreground download service with `downloadTaskCallback`.
  Future<bool> startService({String? statusText}) async {
    if (!Platform.isAndroid) return false;
    initialize();
    try {
      if (await FlutterForegroundTask.isRunningService) {
        if (statusText != null) {
          await FlutterForegroundTask.updateService(
            notificationTitle: AppConstants.foregroundNotificationTitle,
            notificationText: statusText,
          );
        }
        return true;
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: AppConstants.foregroundNotificationTitle,
        notificationText:
            statusText ?? AppConstants.foregroundNotificationBody,
        notificationIcon: null,
        callback: downloadTaskCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (_) {
      return false;
    }
  }

  /// Enqueues a task reliably into the ForegroundService (works from both
  /// `MainActivity` and `ShareModalActivity`, whether service is already up or cold).
  Future<void> enqueueTask(DownloadTask task) async {
    if (!Platform.isAndroid) {
      DownloadQueueManager.instance.addTask(task);
      return;
    }

    initialize();
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({
        'action': 'enqueue',
        'task': task.toJson(),
      });
      // Guard against the narrow race where the service stopped right as data arrived.
      Future.delayed(const Duration(milliseconds: 350), () async {
        if (!await FlutterForegroundTask.isRunningService) {
          await TaskPersistenceService.instance.addPendingEnqueueTask(task);
          await startService(
            statusText: 'Preparando descarga: ${task.title}',
          );
        }
      });
      return;
    }

    await TaskPersistenceService.instance.addPendingEnqueueTask(task);
    final started = await startService(
      statusText: 'Preparando descarga: ${task.title}',
    );
    if (!started && await FlutterForegroundTask.isRunningService) {
      await TaskPersistenceService.instance.removePendingEnqueueTask(task.id);
      FlutterForegroundTask.sendDataToTask({
        'action': 'enqueue',
        'task': task.toJson(),
      });
    }
  }

  Future<void> pauseTask(String taskId) async {
    if (!Platform.isAndroid) {
      await DownloadQueueManager.instance.pauseTask(taskId);
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'pause', 'taskId': taskId});
    } else {
      final tasks = await TaskPersistenceService.instance.loadTasks();
      final updated = tasks
          .map((t) => t.id == taskId
              ? t.copyWith(status: DownloadStatus.paused, speedBytesPerSec: 0)
              : t)
          .toList();
      await TaskPersistenceService.instance.saveTasks(updated);
    }
  }

  Future<void> resumeTask(String taskId) async {
    if (!Platform.isAndroid) {
      DownloadQueueManager.instance.resumeTask(taskId);
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'resume', 'taskId': taskId});
    } else {
      final tasks = await TaskPersistenceService.instance.loadTasks();
      final updated = tasks
          .map((t) => t.id == taskId
              ? t.copyWith(
                  status: DownloadStatus.queued,
                  clearErrorMessage: true,
                )
              : t)
          .toList();
      await TaskPersistenceService.instance.saveTasks(updated);
      await startService(statusText: 'Reanudando descargas...');
    }
  }

  Future<void> cancelTask(String taskId) async {
    if (!Platform.isAndroid) {
      await DownloadQueueManager.instance.cancelTask(taskId);
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'cancel', 'taskId': taskId});
    } else {
      final tasks = await TaskPersistenceService.instance.loadTasks();
      final updated = tasks.where((t) => t.id != taskId).toList();
      await TaskPersistenceService.instance.saveTasks(updated);
    }
  }

  Future<void> retryTask(String taskId) async {
    if (!Platform.isAndroid) {
      DownloadQueueManager.instance.retryTask(taskId);
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'retry', 'taskId': taskId});
    } else {
      final tasks = await TaskPersistenceService.instance.loadTasks();
      final updated = tasks
          .map((t) => t.id == taskId
              ? t.copyWith(
                  status: DownloadStatus.queued,
                  downloadedBytes: 0,
                  speedBytesPerSec: 0,
                  clearErrorMessage: true,
                )
              : t)
          .toList();
      await TaskPersistenceService.instance.saveTasks(updated);
      await startService(statusText: 'Reintentando descarga...');
    }
  }

  Future<void> removeTask(
    String taskId, {
    bool deletePhysicalFile = false,
  }) async {
    if (!Platform.isAndroid) {
      await DownloadQueueManager.instance.removeTask(
        taskId,
        deletePhysicalFile: deletePhysicalFile,
      );
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({
        'action': 'remove',
        'taskId': taskId,
        'deletePhysicalFile': deletePhysicalFile,
      });
    } else {
      final tasks = await TaskPersistenceService.instance.loadTasks();
      final match = tasks.where((t) => t.id == taskId).toList();
      if (deletePhysicalFile && match.isNotEmpty && match.first.savedPath != null) {
        try {
          final file = File(match.first.savedPath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      final updated = tasks.where((t) => t.id != taskId).toList();
      await TaskPersistenceService.instance.saveTasks(updated);
    }
  }

  Future<void> clearCompleted() async {
    if (!Platform.isAndroid) {
      DownloadQueueManager.instance.clearCompleted();
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'clearCompleted'});
    } else {
      await TaskPersistenceService.instance.clearHistory();
    }
  }

  Future<void> updateConcurrency(int limit) async {
    if (!Platform.isAndroid) {
      DownloadQueueManager.instance.setMaxConcurrency(limit);
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({
        'action': 'updateConcurrency',
        'limit': limit,
      });
    }
  }

  Future<void> notifySettingsUpdated() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'reloadSettings'});
    }
  }

  Future<void> requestSync() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'sync'});
    }
  }

  /// Update foreground service notification status text
  Future<void> updateService(String statusText) async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: AppConstants.foregroundNotificationTitle,
          notificationText: statusText,
        );
      }
    } catch (_) {}
  }

  /// Stop foreground task when all downloads are completed
  Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
