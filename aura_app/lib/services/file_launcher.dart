import 'dart:io';

class FileLauncher {
  /// Opens a media file in the system's default media player (VLC, MPV, Windows Media Player, etc.)
  static Future<bool> openFile(String filePath) async {
    if (!File(filePath).existsSync()) return false;

    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Opens the folder containing the file in file manager and highlights/opens it
  static Future<bool> openFolder(String folderOrFilePath) async {
    String folderPath = folderOrFilePath;
    if (File(folderOrFilePath).existsSync()) {
      folderPath = File(folderOrFilePath).parent.path;
    }

    if (!Directory(folderPath).existsSync()) return false;

    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [folderPath]);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [folderPath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
