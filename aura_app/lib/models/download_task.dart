import 'dart:io';
import 'video_item.dart';

enum DownloadStatus {
  queued,
  downloading,
  converting,
  completed,
  paused,
  failed,
  cancelled,
}

enum LogLevel {
  step,
  info,
  warning,
  error,
  success,
}

class TaskLogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  TaskLogEntry({
    required this.timestamp,
    required this.message,
    this.level = LogLevel.info,
  });

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'level': level.index,
  };

  factory TaskLogEntry.fromJson(Map<String, dynamic> json) {
    return TaskLogEntry(
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      message: json['message'] ?? '',
      level: LogLevel.values[(json['level'] as int?)?.clamp(0, LogLevel.values.length - 1) ?? LogLevel.info.index],
    );
  }
}

class DownloadTask {
  final String id;
  final VideoItem video;
  final bool isAudio;
  final String format; // mp3, m4a, flac, mp4
  final String quality; // 320k, 256k, 1080p, 4k, auto
  final String outputPath;
  
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  String speed; // e.g. "5.6 MB/s"
  String eta; // e.g. "2 mins"
  String sizeInfo; // e.g. "1.2 GB / 2.5 GB"
  String? filePath;
  String? errorMessage;
  String engineUsed; // 'yt-dlp (Auto/Fast)', 'pytubefix', 'Pure Dart'
  Process? activeProcess;
  final List<TaskLogEntry> logs;
  final DateTime startTime;

  DownloadTask({
    required this.id,
    required this.video,
    required this.isAudio,
    required this.format,
    required this.quality,
    required this.outputPath,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.speed = '0 KB/s',
    this.eta = '--',
    this.sizeInfo = '0 MB / 0 MB',
    this.filePath,
    this.errorMessage,
    this.engineUsed = 'yt-dlp',
    this.activeProcess,
    List<TaskLogEntry>? logs,
    DateTime? startTime,
  })  : logs = logs ?? [],
        startTime = startTime ?? DateTime.now();

  bool get isRunning => status == DownloadStatus.downloading || status == DownloadStatus.converting;
  bool get isFinished => status == DownloadStatus.completed || status == DownloadStatus.failed || status == DownloadStatus.cancelled;

  void log(String message, {LogLevel level = LogLevel.info}) {
    logs.add(TaskLogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    ));
  }

  int get errorCount => logs.where((l) => l.level == LogLevel.error).length;
  int get warningCount => logs.where((l) => l.level == LogLevel.warning).length;
  int get stepCount => logs.where((l) => l.level == LogLevel.step).length;

  void clearLogs() => logs.clear();
  String exportLogs() => allLogsText;

  String get allLogsText {
    final buffer = StringBuffer();
    buffer.writeln('=== YTDx Studio İşlem ve Hata Günlüğü ===');
    buffer.writeln('Görev ID: $id');
    buffer.writeln('Video: ${video.title} (${video.url})');
    buffer.writeln('Format: ${format.toUpperCase()} | Kalite: $quality | Motor: $engineUsed');
    buffer.writeln('Durum: ${status.name.toUpperCase()}');
    if (filePath != null) buffer.writeln('Hedef Dosya: $filePath');
    if (errorMessage != null) buffer.writeln('Hata: $errorMessage');
    buffer.writeln('--------------------------------------------------');
    for (var l in logs) {
      buffer.writeln('[${l.timeFormatted}] [${l.level.name.toUpperCase()}] ${l.message}');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'video': video.toJson(),
    'isAudio': isAudio,
    'format': format,
    'quality': quality,
    'outputPath': outputPath,
    'status': status.index,
    'progress': progress,
    'sizeInfo': sizeInfo,
    'filePath': filePath,
    'engineUsed': engineUsed,
    'errorMessage': errorMessage,
    'startTime': startTime.toIso8601String(),
    'logs': logs.map((l) => l.toJson()).toList(),
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    List<TaskLogEntry> parsedLogs = [];
    if (json['logs'] is List) {
      parsedLogs = (json['logs'] as List)
          .map((item) => TaskLogEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return DownloadTask(
      id: json['id'] ?? '',
      video: VideoItem.fromJson(Map<String, dynamic>.from(json['video'] ?? {})),
      isAudio: json['isAudio'] ?? true,
      format: json['format'] ?? 'mp3',
      quality: json['quality'] ?? '320k',
      outputPath: json['outputPath'] ?? '',
      status: DownloadStatus.values[(json['status'] as int?)?.clamp(0, DownloadStatus.values.length - 1) ?? DownloadStatus.completed.index],
      progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
      sizeInfo: json['sizeInfo'] ?? '',
      filePath: json['filePath'],
      engineUsed: json['engineUsed'] ?? 'yt-dlp',
      errorMessage: json['errorMessage'],
      startTime: DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),
      logs: parsedLogs,
    );
  }
}
