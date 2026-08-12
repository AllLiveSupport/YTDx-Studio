import 'dart:io';

class BackendLocator {
  static String get projectRoot {
    final home = Platform.environment['HOME'] ?? '';
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    final defaultDir = home.isNotEmpty
        ? '$home/Downloads/YTDx-Youtube-Downloader'
        : (userProfile.isNotEmpty ? '$userProfile\\Downloads\\YTDx-Youtube-Downloader' : '');

    if (Directory(defaultDir).existsSync()) {
      return defaultDir;
    }

    try {
      final exeParent = File(Platform.resolvedExecutable).parent;
      Directory current = exeParent;
      for (int i = 0; i < 6; i++) {
        if (File('${current.path}/pubspec.yaml').existsSync() || Directory('${current.path}/.venv').existsSync()) {
          if (File('${current.path}/pubspec.yaml').existsSync() && current.parent.existsSync()) {
            return current.parent.path;
          }
          return current.path;
        }
        current = current.parent;
      }
    } catch (_) {}

    return Directory.current.path;
  }

  static String findYtDlp() {
    final root = projectRoot;
    final possiblePaths = [
      '$root/.venv/bin/yt-dlp',
      '$root/.venv/Scripts/yt-dlp.exe',
      './.venv/bin/yt-dlp',
      '../.venv/bin/yt-dlp',
      '/usr/local/bin/yt-dlp',
      '/usr/bin/yt-dlp',
      'yt-dlp',
      'C:\\yt-dlp.exe',
    ];

    for (var path in possiblePaths) {
      if (File(path).existsSync()) {
        return File(path).absolute.path;
      }
    }
    return 'yt-dlp';
  }

  static String findFFmpeg() {
    final possiblePaths = [
      '/usr/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
      'ffmpeg',
      'C:\\ffmpeg.exe',
      'C:\\ffmpeg\\bin\\ffmpeg.exe',
    ];

    for (var path in possiblePaths) {
      if (File(path).existsSync()) {
        return File(path).absolute.path;
      }
    }
    return 'ffmpeg';
  }

  static String findPython() {
    final root = projectRoot;
    final possiblePaths = [
      '$root/.venv/bin/python',
      '$root/.venv/Scripts/python.exe',
      './.venv/bin/python',
      '../.venv/bin/python',
      '/usr/bin/python3',
      'python3',
      'python',
    ];

    for (var path in possiblePaths) {
      if (File(path).existsSync()) {
        return File(path).absolute.path;
      }
    }
    return 'python3';
  }

  static String findScript(String scriptRelativePath) {
    final root = projectRoot;
    final possiblePaths = [
      '$root/$scriptRelativePath',
      './$scriptRelativePath',
      '../$scriptRelativePath',
      scriptRelativePath,
    ];

    for (var path in possiblePaths) {
      if (File(path).existsSync()) {
        return File(path).absolute.path;
      }
    }
    return scriptRelativePath;
  }
}
