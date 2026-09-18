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

    task.log('🚀 İndirme görevi başlatıldı: "${task.video.title}"', level: LogLevel.step);
    task.log('⚙️ İstenen Format: ${task.format.toUpperCase()} | Hedef Kalite: ${task.quality.toUpperCase()}', level: LogLevel.info);

    // Ensure output directory exists
    final outDir = Directory(task.outputPath.isNotEmpty ? task.outputPath : settings.downloadPath);
    if (!outDir.existsSync()) {
      try {
        outDir.createSync(recursive: true);
        task.log('📁 Kayıt klasörü oluşturuldu: ${outDir.path}', level: LogLevel.info);
      } catch (e) {
        task.log('⚠️ Klasör oluşturma uyarısı: $e', level: LogLevel.warning);
      }
    } else {
      task.log('📁 Kayıt klasörü: ${outDir.path}', level: LogLevel.info);
    }
    onUpdate();

    bool success = false;

    // Multi-tier Fallback Engine Strategy:
    // Determine priority sequence based on user preference so that NO download ever fails
    final List<String> engineSequence = [];
    if (settings.engine == 'pytubefix') {
      engineSequence.addAll(['pytubefix', 'ytdlp', 'pure_dart']);
    } else if (settings.engine == 'pure_dart') {
      engineSequence.addAll(['pure_dart', 'ytdlp', 'pytubefix']);
    } else {
      // Default: 'auto' or 'ytdlp'
      engineSequence.addAll(['ytdlp', 'pytubefix', 'pure_dart']);
    }

    for (final engine in engineSequence) {
      if (task.status == DownloadStatus.cancelled) {
        task.log('🛑 İndirme kullanıcı tarafından iptal edildi.', level: LogLevel.warning);
        break;
      }

      if (engine == 'ytdlp') {
        task.engineUsed = 'yt-dlp (Auto/Fast)';
        task.log('⚡ 1. Tercih: yt-dlp yüksek performanslı motor çalıştırılıyor...', level: LogLevel.step);
        success = await _downloadWithYtDlp(task, settings, outDir.path, onUpdate);
      } else if (engine == 'pytubefix') {
        task.engineUsed = 'pytubefix';
        task.log('⚡ 2. Tercih: pytubefix motoru çalıştırılıyor...', level: LogLevel.step);
        success = await _downloadWithPytubefix(task, settings, outDir.path, onUpdate);
      } else if (engine == 'pure_dart') {
        task.engineUsed = 'Pure Dart';
        task.log('⚡ 3. Tercih: Pure Dart (YoutubeExplode) sıfır-bağımlılık motoru çalıştırılıyor...', level: LogLevel.step);
        success = await _downloadWithPureDart(task, settings, outDir.path, onUpdate);
      }

      if (success) {
        task.log('🎉 $engine motoru ile indirme başarıyla tamamlandı!', level: LogLevel.success);
        break;
      } else {
        task.log('⚠️ $engine motoru başarısız oldu, sıradaki yedek motora geçiliyor...', level: LogLevel.warning);
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
      if (task.filePath != null && File(task.filePath!).existsSync()) {
        final bytes = File(task.filePath!).lengthSync();
        final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
        task.log('✅ Dosya doğrulandı: ${task.filePath} ($mb MB)', level: LogLevel.success);
      }
      _cleanupResidualTempFiles(outDir.path, task);
    } else if (task.status != DownloadStatus.cancelled) {
      task.status = DownloadStatus.failed;
      task.errorMessage ??= 'Tüm indirme motorları denendi ancak tamamlanamadı.';
      task.log('🛑 HATA: ${task.errorMessage}', level: LogLevel.error);
      _cleanupResidualTempFiles(outDir.path, task);
    }

    onUpdate();
  }

  static Future<String?> _probeVideoCodec(String filePath) async {
    try {
      final ffprobePath = BackendLocator.findFFprobe();
      final res = await Process.run(ffprobePath, [
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=codec_name',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        filePath,
      ]);
      if (res.exitCode == 0) {
        final codec = res.stdout.toString().trim().toLowerCase();
        if (codec.isNotEmpty) return codec;
      }
    } catch (_) {}
    return null;
  }

  static void _cleanupResidualTempFiles(String dirPath, DownloadTask task) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;
      final files = dir.listSync().whereType<File>().toList();
      final title = task.video.title.toLowerCase();
      final sanitizedTitle = _sanitizeFilename(task.video.title).toLowerCase();
      final targetPath = task.filePath?.toLowerCase();
      final isTsTarget = task.format.toLowerCase() == 'ts' || (targetPath != null && targetPath.endsWith('.ts'));

      for (var f in files) {
        final p = f.path;
        final name = f.uri.pathSegments.last.toLowerCase();
        final ext = name.split('.').last;

        // Asla doğrulanmış hedef dosyayı silme
        if (targetPath != null && p.toLowerCase() == targetPath) continue;

        // Dosya bu video ile ilişkili mi kontrol et
        bool isRelated = name.contains(sanitizedTitle) ||
            name.contains(title) ||
            (title.length > 6 && name.contains(title.substring(0, title.length.clamp(0, 20)))) ||
            (sanitizedTitle.length > 6 && name.contains(sanitizedTitle.substring(0, sanitizedTitle.length.clamp(0, 20))));

        if (isRelated) {
          // 1. Meta, parça, önbellek ve görsel artıklarını sil
          if (['meta', 'part', 'ytdl', 'webp', 'jpg', 'aria2'].contains(ext) ||
              name.contains('_temp') ||
              name.contains('_vtmp') ||
              name.contains('_atemp') ||
              name.contains('.temp.')) {
            try { f.deleteSync(); } catch (_) {}
            continue;
          }

          // 2. Hedef TS ise ve geçerli bir .ts üretildiyse, ara MP4/WEBM/MKV dosyasını sil
          if (isTsTarget && targetPath != null && File(targetPath).existsSync() && File(targetPath).lengthSync() > 0) {
            if (['mp4', 'webm', 'mkv'].contains(ext)) {
              try { f.deleteSync(); } catch (_) {}
              continue;
            }
          }
        }

        // Klasördeki 1 dakikadan eski sahipsiz .meta veya .ytdl dosyalarını temizle
        if (ext == 'meta' || ext == 'ytdl') {
          try {
            if (DateTime.now().difference(f.lastModifiedSync()).inMinutes >= 1) {
              f.deleteSync();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
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
      task.log('📡 Pure Dart: Video bilgileri sorgulanıyor...', level: LogLevel.info);
      final video = await yt.videos.get(task.video.url);
      task.log('📡 Pure Dart: Akış manifestosu alınıyor...', level: LogLevel.info);
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

        task.log('🎵 Pure Dart: Ses akışı seçildi (${audioStreamInfo.bitrate}, ${audioStreamInfo.container.name})', level: LogLevel.info);
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
        task.log('🔄 Pure Dart: FFmpeg ile ses dönüştürülüyor ($ext)...', level: LogLevel.step);
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
        } catch (e) {
          task.log('⚠️ FFmpeg ses dönüştürme uyarısı: $e', level: LogLevel.warning);
        }

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
        // Video Download - Select Best Resolution
        VideoStreamInfo? videoStreamInfo;
        final q = task.quality.toLowerCase().trim();

        if (q.contains('4320') || q.contains('8k')) {
          final s8k = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('4320'));
          videoStreamInfo = s8k.where((s) => s.container.name == 'mp4').firstOrNull ?? s8k.firstOrNull;
        } else if (q.contains('2160') || q.contains('4k')) {
          final s4k = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('2160'));
          videoStreamInfo = s4k.where((s) => s.container.name == 'mp4').firstOrNull ?? s4k.firstOrNull;
        } else if (q.contains('1440') || q.contains('2k')) {
          final s1440 = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('1440'));
          videoStreamInfo = s1440.where((s) => s.container.name == 'mp4').firstOrNull ?? s1440.firstOrNull;
        } else if (q.contains('1080')) {
          final s1080 = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('1080'));
          videoStreamInfo = s1080.where((s) => s.container.name == 'mp4').firstOrNull ?? s1080.firstOrNull;
        } else if (q.contains('720')) {
          final s720 = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('720'));
          videoStreamInfo = s720.where((s) => s.container.name == 'mp4').firstOrNull ?? s720.firstOrNull;
        } else if (q.contains('480')) {
          final s480 = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('480'));
          videoStreamInfo = s480.where((s) => s.container.name == 'mp4').firstOrNull ?? s480.firstOrNull;
        } else if (q.contains('360')) {
          final s360 = manifest.videoOnly.where((s) => s.videoQualityLabel.contains('360'));
          videoStreamInfo = s360.where((s) => s.container.name == 'mp4').firstOrNull ?? s360.firstOrNull;
        }

        // Auto or fallback to highest available quality
        if (videoStreamInfo == null) {
          if (manifest.videoOnly.isNotEmpty) {
            final mp4Videos = manifest.videoOnly.where((s) => s.container.name == 'mp4');
            videoStreamInfo = mp4Videos.isNotEmpty ? mp4Videos.withHighestBitrate() : manifest.videoOnly.withHighestBitrate();
          } else if (manifest.muxed.isNotEmpty) {
            videoStreamInfo = manifest.muxed.withHighestBitrate();
          }
        }

        if (videoStreamInfo == null) {
          task.log('❌ Pure Dart: Uygun video akışı bulunamadı.', level: LogLevel.error);
          yt.close();
          return false;
        }

        task.log('🎬 Pure Dart: Seçilen video çözünürlüğü: ${videoStreamInfo.qualityLabel} (${videoStreamInfo.container.name}, ${videoStreamInfo.videoCodec})', level: LogLevel.step);

        final audioStreamInfo = manifest.audioOnly.isNotEmpty
            ? manifest.audioOnly.withHighestBitrate()
            : null;

        final videoExt = videoStreamInfo.container.name;
        final audioExt = audioStreamInfo?.container.name ?? 'm4a';

        final tempVideoPath = '$outputDirPath/${sanitizedTitle}_vtmp.$videoExt';
        final tempAudioPath = '$outputDirPath/${sanitizedTitle}_atmp.$audioExt';
        final targetExt = task.format.toLowerCase() == 'ts' ? 'ts' : 'mp4';
        final finalVideoPath = '$outputDirPath/$sanitizedTitle.$targetExt';

        final vFile = File(tempVideoPath);
        final vStream = yt.videos.streamsClient.get(videoStreamInfo);
        final vOut = vFile.openWrite();

        int downloaded = 0;
        final audioBytes = audioStreamInfo != null ? audioStreamInfo.size.totalBytes : 0;
        final total = videoStreamInfo.size.totalBytes + audioBytes;

        task.log('📥 Pure Dart: Video akışı indiriliyor...', level: LogLevel.info);
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
          task.log('🎵 Pure Dart: Ses akışı indiriliyor...', level: LogLevel.info);
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
          task.log('🔄 Pure Dart: FFmpeg ile ${videoStreamInfo.qualityLabel} video ve ses birleştiriliyor...', level: LogLevel.step);
          onUpdate();

          final isTs = task.format.toLowerCase() == 'ts';
          final codecName = videoStreamInfo.videoCodec.toLowerCase();
          final isNativeTs = codecName.contains('avc') || codecName.contains('h264') || codecName.contains('hevc') || codecName.contains('h265');

          ProcessResult mergeProcess;
          if (isTs && !isNativeTs) {
            task.log('🎬 Pure Dart TS: $codecName video akışı standart H.264 formatına optimize ediliyor...', level: LogLevel.step);
            mergeProcess = await Process.run(ffmpegPath, [
              '-y',
              '-i', tempVideoPath,
              '-i', tempAudioPath,
              '-c:v', 'libx264',
              '-preset', 'veryfast',
              '-crf', '20',
              '-c:a', 'aac',
              finalVideoPath,
            ]);
          } else {
            mergeProcess = await Process.run(ffmpegPath, [
              '-y',
              '-i', tempVideoPath,
              '-i', tempAudioPath,
              '-c:v', 'copy',
              '-c:a', 'aac',
              '-strict', '-2',
              finalVideoPath,
            ]);

            // If stream copy failed, re-encode with fast x264
            if (mergeProcess.exitCode != 0 || !File(finalVideoPath).existsSync()) {
              task.log('⚠️ Doğrudan akış kopyalama başarısız, x264 ile hızlı yeniden kodlanıyor...', level: LogLevel.warning);
              mergeProcess = await Process.run(ffmpegPath, [
                '-y',
                '-i', tempVideoPath,
                '-i', tempAudioPath,
                '-c:v', 'libx264',
                '-preset', 'veryfast',
                '-crf', '20',
                '-c:a', 'aac',
                finalVideoPath,
              ]);
            }
          }

          if (mergeProcess.exitCode == 0 && File(finalVideoPath).existsSync()) {
            if (vFile.existsSync()) vFile.deleteSync();
            if (aFile.existsSync()) aFile.deleteSync();
            task.filePath = finalVideoPath;
            task.log('✅ Pure Dart birleştirme tamamlandı: $finalVideoPath', level: LogLevel.success);
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
      task.errorMessage = 'Pure Dart hatası: $e';
      task.log('❌ Pure Dart istisnası: $e', level: LogLevel.error);
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
      List<String> buildArgs({required bool useCookies, String? playerClient}) {
        final isTs = task.format.toLowerCase() == 'ts';
        final outTemplate = isTs
            ? '$outputDirPath/%(title)s_ytdx_temp.%(ext)s'
            : '$outputDirPath/%(title)s.%(ext)s';

        final List<String> args = [
          '--newline',
          '--no-warnings',
          '--no-check-certificate',
          '--retries', '5',
          '--fragment-retries', '5',
          '--socket-timeout', '30',
          '--concurrent-fragments', '4',
          '--windows-filenames',
          '-o', outTemplate,
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
          final q = task.quality.toLowerCase().trim();
          final isTs = task.format.toLowerCase() == 'ts';
          if (q.contains('4320') || q.contains('8k')) {
            args.addAll(['-f', 'bestvideo[height<=4320]+bestaudio/best']);
          } else if (q.contains('2160') || q.contains('4k')) {
            args.addAll(['-f', 'bestvideo[height<=2160]+bestaudio/best']);
          } else if (q.contains('1440') || q.contains('2k')) {
            args.addAll(['-f', 'bestvideo[height<=1440]+bestaudio/best']);
          } else if (q.contains('1080')) {
            if (isTs) {
              args.addAll(['-f', 'bestvideo[height<=1080][vcodec^=avc1]+bestaudio/bestvideo[height<=1080][vcodec^=h264]+bestaudio/bestvideo[height<=1080]+bestaudio/best']);
            } else {
              args.addAll(['-f', 'bestvideo[height<=1080]+bestaudio/best']);
            }
          } else if (q.contains('720')) {
            if (isTs) {
              args.addAll(['-f', 'bestvideo[height<=720][vcodec^=avc1]+bestaudio/bestvideo[height<=720][vcodec^=h264]+bestaudio/bestvideo[height<=720]+bestaudio/best']);
            } else {
              args.addAll(['-f', 'bestvideo[height<=720]+bestaudio/best']);
            }
          } else if (q.contains('480')) {
            if (isTs) {
              args.addAll(['-f', 'bestvideo[height<=480][vcodec^=avc1]+bestaudio/bestvideo[height<=480][vcodec^=h264]+bestaudio/bestvideo[height<=480]+bestaudio/best']);
            } else {
              args.addAll(['-f', 'bestvideo[height<=480]+bestaudio/best']);
            }
          } else if (q.contains('360')) {
            if (isTs) {
              args.addAll(['-f', 'bestvideo[height<=360][vcodec^=avc1]+bestaudio/bestvideo[height<=360][vcodec^=h264]+bestaudio/bestvideo[height<=360]+bestaudio/best']);
            } else {
              args.addAll(['-f', 'bestvideo[height<=360]+bestaudio/best']);
            }
          } else {
            // Auto / Highest Resolution
            if (isTs) {
              args.addAll(['-f', 'bestvideo[height<=1080][vcodec^=avc1]+bestaudio/bestvideo[height<=1080][vcodec^=h264]+bestaudio/bestvideo+bestaudio/best']);
            } else {
              args.addAll(['-f', 'bestvideo+bestaudio/best']);
            }
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
        final fullCmd = BackendLocator.getYtDlpLaunchArgs(args);
        task.log('▶️ Komut başlatılıyor: ${fullCmd.first} [${args.length} argüman]', level: LogLevel.info);
        final process = await Process.start(fullCmd.first, fullCmd.sublist(1));
        task.activeProcess = process;

        process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((errLine) {
          if (errLine.trim().isNotEmpty && !errLine.contains('WARNING:') && !errLine.contains('DeprecationWarning:')) {
            task.errorMessage = errLine.trim();
            task.log('❌ $errLine', level: LogLevel.error);
          } else if (errLine.contains('WARNING:')) {
            task.log('⚠️ ${errLine.trim()}', level: LogLevel.warning);
          }
        });

        process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          if (line.contains('[info] Downloading 1 format(s):')) {
            task.log('🎯 Seçilen akış formatı: ${line.trim()}', level: LogLevel.step);
          } else if (line.contains('[Merger]') || line.contains('Merging formats into')) {
            task.log('🔄 Ses & Video birleştiriliyor...', level: LogLevel.step);
          } else if (line.contains('[Metadata]') || line.contains('[EmbedThumbnail]')) {
            task.log('🏷️ Meta veriler ve albüm kapağı işleniyor...', level: LogLevel.info);
          }
          _parseProgressLine(line, task);
          onUpdate();
        });

        final code = await process.exitCode;
        task.activeProcess = null;
        return code;
      }

      // Tier 1: Standard / Default multi-client negotiation (No SABR restriction! Full HD/4K/8K)
      task.log('⚡ yt-dlp Tier 1: Standart yüksek çözünürlüklü çoklu istemci çalıştırılıyor...', level: LogLevel.step);
      var exitCode = await runProcessWithArgs(buildArgs(useCookies: true, playerClient: null));

      // Tier 2: If failed and cookies were used, retry without cookies
      if (exitCode != 0 && settings.browserCookies != 'none' && task.status != DownloadStatus.cancelled) {
        task.log('⚡ yt-dlp Tier 2: Çerezler devre dışı bırakılarak yeniden deneniyor...', level: LogLevel.warning);
        exitCode = await runProcessWithArgs(buildArgs(useCookies: false, playerClient: null));
      }

      // Tier 3: If failed, try mweb client
      if (exitCode != 0 && task.status != DownloadStatus.cancelled) {
        task.log('⚡ yt-dlp Tier 3: Mweb istemcisi ile deneniyor...', level: LogLevel.warning);
        exitCode = await runProcessWithArgs(buildArgs(useCookies: false, playerClient: 'mweb'));
      }

      // Tier 4: If failed, try web_creator client
      if (exitCode != 0 && task.status != DownloadStatus.cancelled) {
        task.log('⚡ yt-dlp Tier 4: Web Creator istemcisi ile deneniyor...', level: LogLevel.warning);
        exitCode = await runProcessWithArgs(buildArgs(useCookies: false, playerClient: 'web_creator'));
      }

      if (exitCode == 0) {
        if (task.filePath == null || !File(task.filePath!).existsSync()) {
          task.filePath = _findMatchingFile(outputDirPath, task);
        }

        // If TS format requested, remux/convert to MPEG-TS with FFmpeg
        if (task.format.toLowerCase() == 'ts') {
          final tempCandidates = [
            if (task.filePath != null) task.filePath!,
            _findMatchingFile(outputDirPath, task) ?? '',
          ].where((p) => p.isNotEmpty && File(p).existsSync()).toList();

          if (tempCandidates.isNotEmpty) {
            final currentFile = File(tempCandidates.first);
            if (!currentFile.path.toLowerCase().endsWith('.ts')) {
              task.log('🔍 TS Akış Analizi: Video codec kontrol ediliyor...', level: LogLevel.step);
              final ffmpegPath = BackendLocator.findFFmpeg();
              final tsPath = currentFile.path
                  .replaceAll('_ytdx_temp', '')
                  .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.ts');
              final codec = await _probeVideoCodec(currentFile.path);

              ProcessResult remuxRes;
              if (codec == 'h264' || codec == 'hevc') {
                task.log('⚡ Doğrudan TS Kopyalama: $codec akışı kayıpsız ve yüksek hızda MPEG-TS (.ts) biçimine aktarılıyor...', level: LogLevel.step);
                remuxRes = await Process.run(ffmpegPath, [
                  '-y',
                  '-i', currentFile.path,
                  '-c:v', 'copy',
                  '-c:a', 'aac',
                  tsPath,
                ]);
              } else {
                task.log('🎬 TS Oynatıcı Uyumluluğu: ${codec ?? 'AV1/VP9'} akışı tespit edildi. Haruna, VLC ve TV oynatıcılarıyla tam uyum için standart H.264 video formatına optimize ediliyor...', level: LogLevel.step);
                remuxRes = await Process.run(ffmpegPath, [
                  '-y',
                  '-i', currentFile.path,
                  '-c:v', 'libx264',
                  '-preset', 'veryfast',
                  '-crf', '20',
                  '-c:a', 'aac',
                  tsPath,
                ]);
              }

              if (remuxRes.exitCode == 0 && File(tsPath).existsSync() && File(tsPath).lengthSync() > 0) {
                task.log('✅ MPEG-TS (.ts) başarıyla oluşturuldu: $tsPath', level: LogLevel.success);
                try { currentFile.deleteSync(); } catch (_) {}
                final metaPath = currentFile.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.meta');
                try {
                  final metaFile = File(metaPath);
                  if (metaFile.existsSync()) metaFile.deleteSync();
                } catch (_) {}
                task.filePath = tsPath;
              } else {
                task.log('⚠️ TS dönüştürme uyarısı, orijinal dosya korundu: ${remuxRes.stderr}', level: LogLevel.warning);
              }
            }
          }
        }

        task.log('✅ yt-dlp indirmesi başarılı!', level: LogLevel.success);
        return true;
      }
      task.log('❌ yt-dlp tüm kademelerde başarısız oldu (Çıkış kodu: $exitCode)', level: LogLevel.error);
      return false;
    } catch (e) {
      task.errorMessage = e.toString();
      task.log('❌ yt-dlp istisnası: $e', level: LogLevel.error);
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
      task.log('⚡ Pytubefix Python motoru hazırlanıyor...', level: LogLevel.step);
      final pythonExe = BackendLocator.findPython();
      final runnerScript = BackendLocator.findScript('src/pytube_runner.py');

      final List<String> args = [
        runnerScript,
        '--url', task.video.url,
        '--format', task.format,
        '--quality', task.quality,
        '--output', outputDirPath,
        if (task.isAudio) '--is-audio',
      ];

      task.log('▶️ Python komutu başlatılıyor: $pythonExe $runnerScript', level: LogLevel.info);
      final process = await Process.start(pythonExe, args);
      task.activeProcess = process;

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.contains('[warning]') || line.contains('[error]')) {
          task.log(line.trim(), level: line.contains('[error]') ? LogLevel.error : LogLevel.warning);
        } else if (line.contains('[status]')) {
          task.log(line.trim(), level: LogLevel.info);
        }
        _parseProgressLine(line, task);
        onUpdate();
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((err) {
        if (err.trim().isNotEmpty) {
          task.log('⚠️ $err', level: LogLevel.warning);
        }
      });

      final exitCode = await process.exitCode;
      task.activeProcess = null;

      if (exitCode == 0) {
        if (task.filePath == null || !File(task.filePath!).existsSync()) {
          task.filePath = _findMatchingFile(outputDirPath, task);
        }

        // Check if TS was requested and file needs remux
        if (task.format.toLowerCase() == 'ts' && task.filePath != null && File(task.filePath!).existsSync()) {
          final currentFile = File(task.filePath!);
          if (!currentFile.path.toLowerCase().endsWith('.ts')) {
            task.log('🔍 TS Akış Analizi: Video codec kontrol ediliyor...', level: LogLevel.step);
            final ffmpegPath = BackendLocator.findFFmpeg();
            final tsPath = currentFile.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.ts');
            final codec = await _probeVideoCodec(currentFile.path);

            ProcessResult remuxRes;
            if (codec == 'h264' || codec == 'hevc') {
              task.log('⚡ Doğrudan TS Kopyalama: $codec akışı kayıpsız MPEG-TS formatına aktarılıyor...', level: LogLevel.step);
              remuxRes = await Process.run(ffmpegPath, [
                '-y',
                '-i', currentFile.path,
                '-c:v', 'copy',
                '-c:a', 'aac',
                tsPath,
              ]);
            } else {
              task.log('🎬 TS Oynatıcı Uyumluluğu: ${codec ?? 'AV1/VP9'} akışı standart H.264 formatına optimize ediliyor...', level: LogLevel.step);
              remuxRes = await Process.run(ffmpegPath, [
                '-y',
                '-i', currentFile.path,
                '-c:v', 'libx264',
                '-preset', 'veryfast',
                '-crf', '20',
                '-c:a', 'aac',
                tsPath,
              ]);
            }

            if (remuxRes.exitCode == 0 && File(tsPath).existsSync() && File(tsPath).lengthSync() > 0) {
              task.log('✅ MPEG-TS (.ts) başarıyla oluşturuldu: $tsPath', level: LogLevel.success);
              try { currentFile.deleteSync(); } catch (_) {}
              final metaPath = currentFile.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.meta');
              try {
                final metaFile = File(metaPath);
                if (metaFile.existsSync()) metaFile.deleteSync();
              } catch (_) {}
              task.filePath = tsPath;
            }
          }
        }

        task.log('✅ Pytubefix indirmesi başarılı!', level: LogLevel.success);
        return true;
      }
      task.log('❌ Pytubefix çıkış kodu: $exitCode', level: LogLevel.error);
      return false;
    } catch (e) {
      task.errorMessage = e.toString();
      task.log('❌ Pytubefix istisnası: $e', level: LogLevel.error);
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
        var captured = destMatch.group(1)?.trim().replaceAll('"', '');
        if (captured != null && captured.isNotEmpty) {
          if (captured.endsWith('.part')) {
            captured = captured.substring(0, captured.length - 5);
          } else if (captured.endsWith('.ytdl')) {
            captured = captured.substring(0, captured.length - 5);
          }
          final ext = captured.split('.').last.toLowerCase();
          if (!['meta', 'webp', 'jpg', 'jpeg', 'png', 'json', 'aria2'].contains(ext)) {
            task.filePath = captured;
          }
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

      // Ignore non-media artifacts
      final ignoredExts = {'meta', 'part', 'ytdl', 'webp', 'jpg', 'jpeg', 'png', 'json', 'aria2'};

      // 1. Direct search by words
      final titleWords = task.video.title
          .toLowerCase()
          .split(RegExp(r'[\s\-_\/|\\:,\.]+'))
          .where((w) => w.length > 2)
          .toList();

      for (var f in files) {
        final ext = f.path.split('.').last.toLowerCase();
        if (ignoredExts.contains(ext)) continue;
        if (task.isAudio && !['mp3', 'm4a', 'flac', 'wav', 'opus', 'aac'].contains(ext)) continue;
        if (!task.isAudio && !['ts', 'mp4', 'mkv', 'webm', 'avi', 'mov'].contains(ext)) continue;

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
          if (ignoredExts.contains(ext)) continue;
          if (task.isAudio && ['mp3', 'm4a', 'flac', 'wav', 'opus', 'aac'].contains(ext)) {
            return f.path;
          }
          if (!task.isAudio && ['ts', 'mp4', 'mkv', 'webm', 'avi', 'mov'].contains(ext)) {
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
    task.log('🛑 Görev kullanıcı tarafından iptal edildi.', level: LogLevel.warning);
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
