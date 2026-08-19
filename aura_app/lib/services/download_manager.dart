import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_task.dart';
import '../models/app_settings.dart';
import 'backend_locator.dart';

class DownloadManager {
  static Future<void> executeDownload({
    required DownloadTask task,
    required AppSettings settings,
    required Function() onUpdate,
  }) async {
    task.status = DownloadStatus.downloading;
    task.progress = 0.0;
    task.errorMessage = null;
    onUpdate();

    // Ensure output directory exists
    final outDir = Directory(task.outputPath.isNotEmpty ? task.outputPath : settings.downloadPath);
    if (!outDir.existsSync()) {
      try {
        outDir.createSync(recursive: true);
      } catch (_) {}
    }

    bool success = false;

    if (settings.engine == 'pytubefix') {
      // 1. User selected pytubefix engine
      task.engineUsed = 'pytubefix';
      success = await _downloadWithPytubefix(task, settings, outDir.path, onUpdate);
      if (!success && task.status != DownloadStatus.cancelled) {
        task.engineUsed = 'yt-dlp (Auto/Fast)';
        success = await _downloadWithYtDlp(task, settings, outDir.path, onUpdate);
      }
    } else if (settings.engine == 'ytdlp') {
      // 2. User selected yt-dlp engine
      task.engineUsed = 'yt-dlp (Auto/Fast)';
      success = await _downloadWithYtDlp(task, settings, outDir.path, onUpdate);
    } else {
      // 3. Auto Hybrid (Multi-Tier yt-dlp + Pure Dart fallback)
      task.engineUsed = 'yt-dlp (Auto/Fast)';
      success = await _downloadWithYtDlp(task, settings, outDir.path, onUpdate);
      if (!success && task.status != DownloadStatus.cancelled) {
        task.engineUsed = 'Pure Dart';
        success = await _downloadWithPureDart(task, settings, outDir.path, onUpdate);
      }
    }

    if (success) {
      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.speed = 'Done';
      task.eta = '00:00';

      // Ensure file path is assigned and verified on disk
      if (task.filePath == null || !File(task.filePath!).existsSync()) {
        task.filePath = _findMatchingFile(outDir.path, task);
      }
    } else if (task.status != DownloadStatus.cancelled) {
      task.status = DownloadStatus.failed;
      task.errorMessage ??= 'İndirme tamamlanamadı.';
    }

    onUpdate();
  }

  /// 1. Pure Dart Native Downloader (YoutubeExplode)
  static Future<bool> _downloadWithPureDart(
    DownloadTask task,
    AppSettings settings,
    String outputDirPath,
    Function() onUpdate,
  ) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(task.video.url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      final sanitizedTitle = _sanitizeFilename(video.title);
      final ffmpegPath = BackendLocator.findFFmpeg();

      if (task.isAudio) {
        // Find best audio stream
        final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        final ext = task.format.toLowerCase();
        final finalFilePath = '$outputDirPath/$sanitizedTitle.$ext';
        final tempRawPath = '$outputDirPath/${sanitizedTitle}_temp.${audioStreamInfo.container.name}';
        final tempFile = File(tempRawPath);

        final outputStream = tempFile.openWrite();
        final stream = yt.videos.streamsClient.get(audioStreamInfo);

        int downloaded = 0;
        final total = audioStreamInfo.size.totalBytes;
        final stopwatch = Stopwatch()..start();

        await for (final chunk in stream) {
          if (task.status == DownloadStatus.cancelled) {
            await outputStream.close();
            if (tempFile.existsSync()) tempFile.deleteSync();
            yt.close();
            return false;
          }

          downloaded += chunk.length;
          outputStream.add(chunk);

          task.progress = downloaded / total;
          final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
          if (elapsedSec > 0) {
            final mbps = (downloaded / (1024 * 1024)) / elapsedSec;
            task.speed = '${mbps.toStringAsFixed(1)} MB/s';
            final remainingBytes = total - downloaded;
            final remainingSec = mbps > 0 ? (remainingBytes / (1024 * 1024)) / mbps : 0;
            task.eta = remainingSec > 60
                ? '${(remainingSec / 60).toInt()}m ${(remainingSec % 60).toInt()}s'
                : '${remainingSec.toInt()}s';
          }
          task.sizeInfo = '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
          onUpdate();
        }

        await outputStream.flush();
        await outputStream.close();
        stopwatch.stop();

        // Convert to desired audio format (MP3 320k, M4A, FLAC) with FFmpeg
        task.status = DownloadStatus.converting;
        task.speed = 'Dönüştürülüyor...';
        onUpdate();

        bool converted = false;
        try {
          final bitRateArg = task.quality == '320k' ? '320k' : '256k';
          final convertProcess = await Process.run(ffmpegPath, [
            '-i', tempRawPath,
            if (ext == 'mp3') ...['-c:a', 'libmp3lame', '-b:a', bitRateArg]
            else if (ext == 'm4a') ...['-c:a', 'aac', '-b:a', bitRateArg]
            else if (ext == 'flac') ...['-c:a', 'flac'],
            '-y',
            finalFilePath,
          ]);

          if (convertProcess.exitCode == 0 && File(finalFilePath).existsSync()) {
            converted = true;
            if (tempFile.existsSync()) tempFile.deleteSync();
            task.filePath = finalFilePath;
          }
        } catch (_) {}

        if (!converted) {
          final rawFinalPath = '$outputDirPath/$sanitizedTitle.${audioStreamInfo.container.name}';
          if (tempFile.existsSync()) {
            tempFile.renameSync(rawFinalPath);
            task.filePath = rawFinalPath;
          }
        }

        yt.close();
        return true;
      } else {
        // Video Download
        StreamInfo? videoStreamInfo;
        
        // Find best video stream according to requested quality
        if (task.quality.contains('1080')) {
          videoStreamInfo = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('1080')).firstOrNull;
        } else if (task.quality.contains('720')) {
          videoStreamInfo = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('720')).firstOrNull;
        } else if (task.quality.contains('4k') || task.quality.contains('2160')) {
          videoStreamInfo = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('2160')).firstOrNull;
        } else if (task.quality.contains('1440') || task.quality.contains('2k')) {
          videoStreamInfo = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('1440')).firstOrNull;
        } else if (task.quality.contains('480')) {
          videoStreamInfo = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('480')).firstOrNull;
        }

        if (videoStreamInfo == null) {
          if (manifest.videoOnly.isNotEmpty) {
            videoStreamInfo = manifest.videoOnly.withHighestBitrate();
          } else if (manifest.muxed.isNotEmpty) {
            videoStreamInfo = manifest.muxed.withHighestBitrate();
          }
        }

        if (videoStreamInfo == null) {
          yt.close();
          return false;
        }

        final audioStreamInfo = manifest.audioOnly.isNotEmpty
            ? manifest.audioOnly.withHighestBitrate()
            : null;

        final tempVideoPath = '$outputDirPath/${sanitizedTitle}_vtmp.mp4';
        final tempAudioPath = '$outputDirPath/${sanitizedTitle}_atmp.m4a';
        final finalVideoPath = '$outputDirPath/$sanitizedTitle.mp4';

        final vFile = File(tempVideoPath);
        final vStream = yt.videos.streamsClient.get(videoStreamInfo);
        final vOut = vFile.openWrite();

        int downloaded = 0;
        final audioBytes = audioStreamInfo != null ? audioStreamInfo.size.totalBytes : 0;
        final total = videoStreamInfo.size.totalBytes + audioBytes;

        await for (final chunk in vStream) {
          if (task.status == DownloadStatus.cancelled) {
            await vOut.close();
            if (vFile.existsSync()) vFile.deleteSync();
            yt.close();
            return false;
          }
          downloaded += chunk.length;
          vOut.add(chunk);
          task.progress = (downloaded / total) * (audioStreamInfo != null ? 0.7 : 1.0);
          task.sizeInfo = '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
          onUpdate();
        }
        await vOut.flush();
        await vOut.close();

        // Download audio track if separate
        if (audioStreamInfo != null) {
          final aFile = File(tempAudioPath);
          final aStream = yt.videos.streamsClient.get(audioStreamInfo);
          final aOut = aFile.openWrite();

          await for (final chunk in aStream) {
            if (task.status == DownloadStatus.cancelled) {
              await aOut.close();
              if (aFile.existsSync()) aFile.deleteSync();
              if (vFile.existsSync()) vFile.deleteSync();
              yt.close();
              return false;
            }
            downloaded += chunk.length;
            aOut.add(chunk);
            task.progress = (downloaded / total);
            task.sizeInfo = '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
            onUpdate();
          }
          await aOut.flush();
          await aOut.close();

          // Merge with FFmpeg
          task.status = DownloadStatus.converting;
          task.speed = 'Ses & Video Birleştiriliyor...';
          onUpdate();

          final mergeProcess = await Process.run(ffmpegPath, [
            '-i', tempVideoPath,
            '-i', tempAudioPath,
            '-c:v', 'copy',
            '-c:a', 'aac',
            '-y',
            finalVideoPath,
          ]);

          if (mergeProcess.exitCode == 0 && File(finalVideoPath).existsSync()) {
            if (vFile.existsSync()) vFile.deleteSync();
            if (aFile.existsSync()) aFile.deleteSync();
            task.filePath = finalVideoPath;
            yt.close();
            return true;
          }
        } else {
          if (vFile.existsSync()) {
            vFile.renameSync(finalVideoPath);
            task.filePath = finalVideoPath;
            yt.close();
            return true;
          }
        }

        yt.close();
        return false;
      }
    } catch (e) {
      yt.close();
      return false;
    }
  }

  /// 2. Subprocess Downloader (yt-dlp with Multi-Tier Client Fallback Matrix)
  static Future<bool> _downloadWithYtDlp(
    DownloadTask task,
    AppSettings settings,
    String outputDirPath,
    Function() onUpdate,
  ) async {
    try {
      final ytdlpExe = BackendLocator.findYtDlp();

      List<String> buildArgs({required bool useCookies, String? playerClient}) {
        final List<String> args = [
          '--newline',
          '--no-warnings',
          '--no-check-certificate',
          '--retries', '5',
          '--fragment-retries', '5',
          '--socket-timeout', '30',
          '--concurrent-fragments', '4',
          '--windows-filenames',
          '-o', '$outputDirPath/%(title)s.%(ext)s',
        ];

        if (playerClient != null && playerClient.isNotEmpty) {
          args.addAll(['--extractor-args', 'youtube:player_client=$playerClient']);
        }

        // Safe cookies
        if (useCookies && settings.browserCookies != 'none') {
          args.addAll(['--cookies-from-browser', settings.browserCookies]);
        }

        if (task.isAudio) {
          args.addAll([
            '-x',
            '--audio-format', task.format,
            '--audio-quality', task.quality == '320k' ? '0' : '2',
            '--embed-thumbnail',
            '--add-metadata',
          ]);
        } else {
          if (task.quality.contains('4320') || task.quality.contains('8k')) {
            args.addAll(['-f', 'bestvideo[height<=4320]+bestaudio/best']);
          } else if (task.quality.contains('2160') || task.quality.contains('4k')) {
            args.addAll(['-f', 'bestvideo[height<=2160]+bestaudio/best']);
          } else if (task.quality.contains('1440') || task.quality.contains('2k')) {
            args.addAll(['-f', 'bestvideo[height<=1440]+bestaudio/best']);
          } else if (task.quality.contains('1080')) {
            args.addAll(['-f', 'bestvideo[height<=1080]+bestaudio/best']);
          } else if (task.quality.contains('720')) {
            args.addAll(['-f', 'bestvideo[height<=720]+bestaudio/best']);
          } else if (task.quality.contains('480')) {
            args.addAll(['-f', 'bestvideo[height<=480]+bestaudio/best']);
          } else if (task.quality.contains('360')) {
            args.addAll(['-f', 'bestvideo[height<=360]+bestaudio/best']);
          } else {
            args.addAll(['-f', 'bestvideo+bestaudio/best']);
          }
          args.addAll([
            '--merge-output-format', 'mp4',
            '--embed-thumbnail',
            '--add-metadata',
          ]);
        }

        args.add(task.video.url);
        return args;
      }

      Future<int> runProcessWithArgs(List<String> args) async {
        final process = await Process.start(ytdlpExe, args);
        task.activeProcess = process;

        process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((errLine) {
          if (errLine.trim().isNotEmpty && !errLine.contains('WARNING:') && !errLine.contains('DeprecationWarning:')) {
            task.errorMessage = errLine.trim();
          }
        });

        process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          _parseProgressLine(line, task);
          onUpdate();
        });

        final code = await process.exitCode;
        task.activeProcess = null;
        return code;
      }

      // Tier 1: Primary Modern Client ('android,web')
      var exitCode = await runProcessWithArgs(buildArgs(useCookies: true, playerClient: 'android,web'));

      // Tier 2: If failed and cookies were used, retry without cookies
      if (exitCode != 0 && settings.browserCookies != 'none' && task.status != DownloadStatus.cancelled) {
        exitCode = await runProcessWithArgs(buildArgs(useCookies: false, playerClient: 'android,web'));
      }

      // Tier 3: If failed (e.g. 403 or SABR issue), try pure 'android' client
      if (exitCode != 0 && task.status != DownloadStatus.cancelled) {
        exitCode = await runProcessWithArgs(buildArgs(useCookies: false, playerClient: 'android'));
      }

      // Tier 4: If failed, try 'android,mweb' client
      if (exitCode != 0 && task.status != DownloadStatus.cancelled) {
        exitCode = await runProcessWithArgs(buildArgs(useCookies: false, playerClient: 'android,mweb'));
      }

      // Tier 5: If still failed, try standard default yt-dlp client without extractor-args
      if (exitCode != 0 && task.status != DownloadStatus.cancelled) {
        exitCode = await runProcessWithArgs(buildArgs(useCookies: false, playerClient: null));
      }

      if (exitCode == 0) {
        if (task.filePath == null || !File(task.filePath!).existsSync()) {
          task.filePath = _findMatchingFile(outputDirPath, task);
        }
        return true;
      }
      return false;
    } catch (e) {
      task.errorMessage = e.toString();
      return false;
    }
  }

  /// 3. Pytubefix Python Engine Runner
  static Future<bool> _downloadWithPytubefix(
    DownloadTask task,
    AppSettings settings,
    String outputDirPath,
    Function() onUpdate,
  ) async {
    try {
      final pythonExe = BackendLocator.findPython();
      final projectPaths = [
        '../src/pytube_runner.py',
        'src/pytube_runner.py',
        '${Platform.environment['HOME']}/Downloads/YTDx-Youtube-Downloader/src/pytube_runner.py',
        '${Platform.environment['USERPROFILE']}\\Downloads\\YTDx-Youtube-Downloader\\src\\pytube_runner.py',
      ];

      String runnerScript = 'src/pytube_runner.py';
      for (var p in projectPaths) {
        if (File(p).existsSync()) {
          runnerScript = File(p).absolute.path;
          break;
        }
      }

      final List<String> args = [
        runnerScript,
        '--url', task.video.url,
        '--format', task.format,
        '--quality', task.quality,
        '--output', outputDirPath,
        if (task.isAudio) '--is-audio',
      ];

      final process = await Process.start(pythonExe, args);
      task.activeProcess = process;

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        _parseProgressLine(line, task);
        onUpdate();
      });

      final exitCode = await process.exitCode;
      task.activeProcess = null;

      if (exitCode == 0) {
        if (task.filePath == null || !File(task.filePath!).existsSync()) {
          task.filePath = _findMatchingFile(outputDirPath, task);
        }
        return true;
      }
      return false;
    } catch (e) {
      task.errorMessage = e.toString();
      return false;
    }
  }

  static void _parseProgressLine(String line, DownloadTask task) {
    if (line.contains('[download]') && line.contains('%')) {
      try {
        final percentMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(line);
        double pct = 0.0;
        if (percentMatch != null) {
          pct = double.tryParse(percentMatch.group(1) ?? '0') ?? 0.0;
          task.progress = (pct / 100.0).clamp(0.0, 1.0);
        }

        final sizeMatch = RegExp(r'of\s+([~0-9\.]+[KMG]i?B)').firstMatch(line);
        if (sizeMatch != null) {
          final totalStr = sizeMatch.group(1) ?? '';
          final numStr = totalStr.replaceAll(RegExp(r'[^0-9\.]'), '');
          final totalVal = double.tryParse(numStr) ?? 0.0;
          final unit = totalStr.replaceAll(RegExp(r'[0-9\.\s~]'), '');
          final downVal = totalVal * (pct / 100.0);
          task.sizeInfo = '${downVal.toStringAsFixed(1)} $unit / ${totalVal.toStringAsFixed(1)} $unit';
        }

        final speedMatch = RegExp(r'at\s+([0-9\.]+[KMG]i?B/s)').firstMatch(line);
        if (speedMatch != null) {
          task.speed = speedMatch.group(1) ?? task.speed;
        }

        final etaMatch = RegExp(r'ETA\s+([0-9:]+)').firstMatch(line);
        if (etaMatch != null) {
          task.eta = etaMatch.group(1) ?? task.eta;
        }
      } catch (_) {}
    } else if (line.contains('[ExtractAudio]') || line.contains('[Merger]') || line.contains('Albüm kapak resmi')) {
      task.status = DownloadStatus.converting;
      task.speed = 'Dönüştürülüyor...';
    }

    // Capture destination path
    if (line.contains('Destination:') || line.contains('Merging formats into') || line.contains('FILE_EXISTS:')) {
      final destMatch = RegExp(r'Destination:\s*(.+)$').firstMatch(line) ??
          RegExp(r'Merging formats into "(.+)"').firstMatch(line) ??
          RegExp(r'FILE_EXISTS:[^:]+:(.+)$').firstMatch(line);
      if (destMatch != null) {
        final captured = destMatch.group(1)?.trim().replaceAll('"', '');
        if (captured != null && captured.isNotEmpty) {
          task.filePath = captured;
        }
      }
    }
  }

  static String? _findMatchingFile(String outputDirPath, DownloadTask task) {
    try {
      final dir = Directory(outputDirPath);
      if (!dir.existsSync()) return null;

      final files = dir.listSync().whereType<File>().toList();
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // 1. Direct search by words
      final titleWords = task.video.title
          .toLowerCase()
          .split(RegExp(r'[\s\-_\/|\\:,\.]+'))
          .where((w) => w.length > 2)
          .toList();

      for (var f in files) {
        final name = f.uri.pathSegments.last.toLowerCase();
        int matchCount = 0;
        for (var w in titleWords) {
          if (name.contains(w)) matchCount++;
        }
        if (titleWords.isNotEmpty && (matchCount / titleWords.length) >= 0.5) {
          return f.path;
        }
      }

      // 2. Search most recent matching extension (downloaded in last 10 minutes)
      for (var f in files) {
        final diff = DateTime.now().difference(f.lastModifiedSync()).inMinutes;
        if (diff <= 10) {
          final ext = f.path.split('.').last.toLowerCase();
          if (task.isAudio && ['mp3', 'm4a', 'flac', 'wav', 'opus', 'aac'].contains(ext)) {
            return f.path;
          }
          if (!task.isAudio && ['mp4', 'mkv', 'webm', 'avi', 'mov'].contains(ext)) {
            return f.path;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static void cancelTask(DownloadTask task) {
    task.status = DownloadStatus.cancelled;
    try {
      task.activeProcess?.kill(ProcessSignal.sigkill);
    } catch (_) {
      try {
        task.activeProcess?.kill();
      } catch (_) {}
    }
    task.activeProcess = null;
  }
}
