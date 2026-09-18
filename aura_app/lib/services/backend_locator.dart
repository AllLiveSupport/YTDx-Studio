import 'dart:io';

class BackendLocator {
  static String? _cachedProjectRoot;

  static String get projectRoot {
    if (_cachedProjectRoot != null) {
      return _cachedProjectRoot!;
    }

    // 1. Environment variable override
    final envRoot = Platform.environment['YTDX_PROJECT_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty && Directory(envRoot).existsSync()) {
      _cachedProjectRoot = envRoot;
      return envRoot;
    }

    // 2. Discover from Platform.resolvedExecutable
    try {
      final exeFile = File(Platform.resolvedExecutable);
      Directory current = exeFile.parent;
      for (int i = 0; i < 6; i++) {
        if (Directory('${current.path}/.venv').existsSync() ||
            File('${current.path}/requirements.txt').existsSync() ||
            Directory('${current.path}/src').existsSync()) {
          _cachedProjectRoot = current.path;
          return current.path;
        }
        if (File('${current.path}/pubspec.yaml').existsSync() && current.parent.existsSync()) {
          final parent = current.parent;
          if (Directory('${parent.path}/.venv').existsSync() ||
              File('${parent.path}/requirements.txt').existsSync() ||
              Directory('${parent.path}/src').existsSync()) {
            _cachedProjectRoot = parent.path;
            return parent.path;
          }
        }
        current = current.parent;
      }
    } catch (_) {}

    // 3. Discover from Directory.current
    try {
      Directory current = Directory.current;
      for (int i = 0; i < 5; i++) {
        if (Directory('${current.path}/.venv').existsSync() ||
            File('${current.path}/requirements.txt').existsSync() ||
            Directory('${current.path}/src').existsSync()) {
          _cachedProjectRoot = current.path;
          return current.path;
        }
        if (File('${current.path}/pubspec.yaml').existsSync() && current.parent.existsSync()) {
          final parent = current.parent;
          if (Directory('${parent.path}/.venv').existsSync() ||
              File('${parent.path}/requirements.txt').existsSync() ||
              Directory('${parent.path}/src').existsSync()) {
            _cachedProjectRoot = parent.path;
            return parent.path;
          }
        }
        current = current.parent;
      }
    } catch (_) {}

    _cachedProjectRoot = Directory.current.path;
    return _cachedProjectRoot!;
  }

  static String findYtDlp() {
    final root = projectRoot;
    final home = Platform.environment['HOME'] ?? '';
    final possiblePaths = [
      '$root/.venv/bin/yt-dlp',
      '$root/.venv/Scripts/yt-dlp.exe',
      './.venv/bin/yt-dlp',
      '../.venv/bin/yt-dlp',
      if (home.isNotEmpty) '$home/.local/bin/yt-dlp',
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

  /// Returns executable and command args for launching yt-dlp,
  /// falling back to [python, -m, yt_dlp] if yt-dlp binary is not standalone.
  static List<String> getYtDlpLaunchArgs(List<String> downloadArgs) {
    final ytdlpPath = findYtDlp();
    if (File(ytdlpPath).existsSync()) {
      return [ytdlpPath, ...downloadArgs];
    }
    // Fallback to executing via python -m yt_dlp
    final pythonPath = findPython();
    return [pythonPath, '-m', 'yt_dlp', ...downloadArgs];
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

  static String findFFprobe() {
    final possiblePaths = [
      '/usr/bin/ffprobe',
      '/usr/local/bin/ffprobe',
      'ffprobe',
      'C:\\ffprobe.exe',
      'C:\\ffmpeg\\bin\\ffprobe.exe',
    ];

    for (var path in possiblePaths) {
      if (File(path).existsSync()) {
        return File(path).absolute.path;
      }
    }
    return 'ffprobe';
  }

  static String findPython() {
    final root = projectRoot;
    final possiblePaths = [
      '$root/.venv/bin/python',
      '$root/.venv/bin/python3',
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
      '${Directory.current.path}/$scriptRelativePath',
      '${Directory.current.parent.path}/$scriptRelativePath',
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
