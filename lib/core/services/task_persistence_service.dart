import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../features/downloader/data/models/download_task.dart';
import 'settings_service.dart';

/// TaskPersistenceService — persists download queue & completed history across
/// isolates (`MainActivity`, `ShareModalActivity`, and `ForegroundService`).
class TaskPersistenceService {
  TaskPersistenceService._();
  static final TaskPersistenceService instance = TaskPersistenceService._();

  Future<SharedPreferences> _prefs({bool reload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) {
      await prefs.reload();
    }
    return prefs;
  }

  /// Loads all saved tasks from disk.
  /// If [recoverInterrupted] is true, any task left in `downloading` state from
  /// a killed process is converted back to `queued` (or `paused`) so it can resume.
  Future<List<DownloadTask>> loadTasks({bool recoverInterrupted = false}) async {
    try {
      final prefs = await _prefs(reload: true);
      final raw = prefs.getString(AppConstants.prefTasksHistory);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = <DownloadTask>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          var task = DownloadTask.fromJson(item);
          if (recoverInterrupted && task.status == DownloadStatus.downloading) {
            task = task.copyWith(
              status: DownloadStatus.queued,
              speedBytesPerSec: 0.0,
            );
          }
          list.add(task);
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Saves the task list to disk. Respects `saveDownloadHistory` preference for
  /// terminal completed tasks while always keeping active/paused/failed tasks.
  Future<void> saveTasks(List<DownloadTask> tasks) async {
    try {
      final prefs = await _prefs();
      await SettingsService.instance.initialize();
      final saveHistory = SettingsService.instance.getSaveDownloadHistory();

      final toPersist = tasks.where((t) {
        if (t.status == DownloadStatus.canceled) return false;
        if (t.status == DownloadStatus.completed && !saveHistory) return false;
        return true;
      }).toList();

      final encoded = jsonEncode(toPersist.map((t) => t.toJson()).toList());
      await prefs.setString(AppConstants.prefTasksHistory, encoded);
    } catch (_) {}
  }

  /// Adds a task to the pending inbox before starting the ForegroundService.
  Future<void> addPendingEnqueueTask(DownloadTask task) async {
    try {
      final prefs = await _prefs(reload: true);
      final raw = prefs.getString(AppConstants.prefPendingEnqueueTasks);
      final List<dynamic> current =
          (raw != null && raw.isNotEmpty) ? (jsonDecode(raw) as List<dynamic>) : [];

      current.removeWhere(
        (e) => e is Map<String, dynamic> && e['id'] == task.id,
      );
      current.add(task.toJson());
      await prefs.setString(
        AppConstants.prefPendingEnqueueTasks,
        jsonEncode(current),
      );
    } catch (_) {}
  }

  /// Reads and clears any pending tasks waiting to be picked up by the ForegroundService.
  Future<List<DownloadTask>> takePendingEnqueueTasks() async {
    try {
      final prefs = await _prefs(reload: true);
      final raw = prefs.getString(AppConstants.prefPendingEnqueueTasks);
      if (raw == null || raw.isEmpty) return [];

      await prefs.remove(AppConstants.prefPendingEnqueueTasks);
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DownloadTask.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Removes a single pending task (used if IPC fallback took over).
  Future<void> removePendingEnqueueTask(String taskId) async {
    try {
      final prefs = await _prefs(reload: true);
      final raw = prefs.getString(AppConstants.prefPendingEnqueueTasks);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      decoded.removeWhere((e) => e is Map<String, dynamic> && e['id'] == taskId);
      await prefs.setString(
        AppConstants.prefPendingEnqueueTasks,
        jsonEncode(decoded),
      );
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    final current = await loadTasks();
    final remaining = current
        .where((t) => t.status != DownloadStatus.completed && !t.isTerminal)
        .toList();
    await saveTasks(remaining);
  }
}
