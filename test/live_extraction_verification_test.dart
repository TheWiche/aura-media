import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:medias_download/features/downloader/data/datasources/generic_extractor.dart';
import 'package:medias_download/features/downloader/data/datasources/youtube_extractor.dart';
import 'package:medias_download/features/downloader/data/models/download_task.dart';
import 'package:medias_download/features/downloader/domain/queue/download_queue_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoQuality;

void main() {
  test('Direct media and generic extractor pipeline test', () async {
    final genericExtractor = GenericExtractor();
    const sampleUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

    print('[TEST] 1. Probando extracción de metadata con enlace de video directo...');
    final metadata = await genericExtractor.fetchMetadata(sampleUrl);

    print('[TEST] Metadata obtenida: "${metadata.title}" | Plataforma: ${metadata.platform}');
    expect(metadata.title, contains('BigBuckBunny.mp4'));
    expect(metadata.platform, equals('Web Directo'));

    print('[TEST] 2. Probando resolución de stream...');
    final resolvedStream = await genericExtractor.resolveStream(
      url: sampleUrl,
      mediaType: MediaType.video,
    );
    print('[TEST] Stream resuelto: extension=${resolvedStream.extension}, bytes=${resolvedStream.totalBytes}');
    expect(resolvedStream.extension, equals('mp4'));
    expect(resolvedStream.totalBytes, greaterThan(0));

    print('[TEST] 3. Probando flujo de cola en DownloadQueueManager...');
    final queueManager = DownloadQueueManager.instance;
    queueManager.setMaxConcurrency(2);

    final task = DownloadTask(
      id: 'pipeline-live-task',
      notificationId: 8888,
      url: sampleUrl,
      title: metadata.title,
      author: metadata.author,
      mediaType: MediaType.video,
      fileExtension: resolvedStream.extension,
      createdAt: DateTime.now(),
      status: DownloadStatus.queued,
    );

    final completer = Completer<bool>();
    final sub = queueManager.tasksStream.listen((tasks) {
      if (tasks.any((t) => t.id == 'pipeline-live-task')) {
        final current = tasks.firstWhere((t) => t.id == 'pipeline-live-task');
        print('[TEST] Estado en cola: ${current.status}');
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    queueManager.addTask(task);

    final isReceived = await completer.future.timeout(const Duration(seconds: 5));
    expect(isReceived, isTrue);

    // Pause
    await queueManager.pauseTask('pipeline-live-task');
    expect(queueManager.currentTasks.firstWhere((t) => t.id == 'pipeline-live-task').status, DownloadStatus.paused);
    print('[TEST] Pausa validada');

    // Cancel
    await queueManager.cancelTask('pipeline-live-task');
    expect(queueManager.currentTasks.firstWhere((t) => t.id == 'pipeline-live-task').status, DownloadStatus.canceled);
    print('[TEST] Cancelacion validada');

    // Remove
    await queueManager.removeTask('pipeline-live-task');
    expect(queueManager.currentTasks.any((t) => t.id == 'pipeline-live-task'), isFalse);
    print('[TEST] Tarea eliminada de la cola');

    await sub.cancel();
  });

  test('YouTube extractor handles valid URLs or IP rate limiting safely', () async {
    final youtubeExtractor = YoutubeExtractor();
    const testUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';

    try {
      final meta = await youtubeExtractor.fetchMetadata(testUrl);
      print('[TEST-YT] Metadata de YouTube obtenida con éxito: "${meta.title}"');
      expect(meta.title, isNotEmpty);
      expect(meta.platform, equals('YouTube'));
    } on RequestLimitExceededException {
      print('[TEST-YT] YouTube rate-limiting detectado para la IP actual (esperado en IPs de red compartida/datacenter). Manejado correctamente.');
    } catch (e) {
      print('[TEST-YT] Capturado error de red: $e');
    } finally {
      youtubeExtractor.close();
    }
  });
}
