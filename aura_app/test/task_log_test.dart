import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/models/download_task.dart';
import 'package:aura_app/models/video_item.dart';

void main() {
  group('DownloadTask Logging Tests', () {
    test('Logs entries and updates metrics accurately', () {
      final video = VideoItem(
        id: 'dQw4w9WgXcQ',
        title: 'Rick Astley - Never Gonna Give You Up',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        channel: 'Rick Astley',
        duration: '03:32',
        thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/0.jpg',
      );

      final task = DownloadTask(
        id: 'test-1',
        video: video,
        isAudio: false,
        quality: '1080p',
        format: 'mp4',
        outputPath: '/tmp',
        status: DownloadStatus.downloading,
      );

      expect(task.logs.isEmpty, isTrue);
      expect(task.errorCount, equals(0));
      expect(task.warningCount, equals(0));
      expect(task.stepCount, equals(0));

      task.log('İndirme başlatılıyor', level: LogLevel.step);
      task.log('Motor 1 deneniyor: yt-dlp', level: LogLevel.info);
      task.log('Beklenmeyen uyarı', level: LogLevel.warning);
      task.log('Hata oluştu', level: LogLevel.error);
      task.log('Tamamlandı', level: LogLevel.success);

      expect(task.logs.length, equals(5));
      expect(task.stepCount, equals(1));
      expect(task.warningCount, equals(1));
      expect(task.errorCount, equals(1));

      final exported = task.exportLogs();
      expect(exported.contains('[STEP] İndirme başlatılıyor'), isTrue);
      expect(exported.contains('[INFO] Motor 1 deneniyor: yt-dlp'), isTrue);
      expect(exported.contains('[WARNING] Beklenmeyen uyarı'), isTrue);
      expect(exported.contains('[ERROR] Hata oluştu'), isTrue);
      expect(exported.contains('[SUCCESS] Tamamlandı'), isTrue);
    });

    test('Clear logs resets log entries', () {
      final video = VideoItem(
        id: 'test-id',
        title: 'Test 4K Video',
        url: 'https://www.youtube.com/watch?v=test',
        channel: 'Test Channel',
        duration: '01:00',
        thumbnail: '',
      );

      final task = DownloadTask(
        id: 'test-2',
        video: video,
        isAudio: false,
        quality: '4K',
        format: 'mp4',
        outputPath: '/tmp',
        status: DownloadStatus.queued,
      );

      task.log('Step 1', level: LogLevel.step);
      expect(task.logs.length, equals(1));
      task.clearLogs();
      expect(task.logs.length, equals(0));
    });

    test('Supports TS (MPEG Transport Stream) format and logs', () {
      final video = VideoItem(
        id: 'test-ts-id',
        title: 'MPEG-TS Live Video',
        url: 'https://www.youtube.com/watch?v=ts_test',
        channel: 'Broadcast Channel',
        duration: '02:00',
        thumbnail: '',
      );

      final task = DownloadTask(
        id: 'test-3',
        video: video,
        isAudio: false,
        quality: '1080p',
        format: 'ts',
        outputPath: '/tmp',
        status: DownloadStatus.queued,
      );

      expect(task.format, equals('ts'));
      task.log('🔄 TS Dönüştürme: FFmpeg ile MPEG Transport Stream (.ts) formatına aktarılıyor...', level: LogLevel.step);
      expect(task.exportLogs().contains('Format: TS'), isTrue);
      expect(task.exportLogs().contains('TS Dönüştürme'), isTrue);
    });
  });
}
