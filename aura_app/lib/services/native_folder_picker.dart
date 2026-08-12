import 'dart:io';
import 'package:file_picker/file_picker.dart';

class NativeFolderPicker {
  /// Opens a native directory picker dialog and returns the selected path
  static Future<String?> pickDirectory({String? initialPath, String? title}) async {
    // 1. Try file_picker package first
    try {
      final selected = await FilePicker.getDirectoryPath(
        dialogTitle: title ?? 'İndirme Klasörünü Seçin',
        initialDirectory: initialPath,
      );
      if (selected != null && selected.isNotEmpty) {
        return selected;
      }
    } catch (_) {}

    // 2. Linux native fallback: zenity or kdialog
    if (Platform.isLinux) {
      try {
        final result = await Process.run('zenity', [
          '--file-selection',
          '--directory',
          '--title=${title ?? "İndirme Klasörünü Seçin"}',
          if (initialPath != null && initialPath.isNotEmpty) '--filename=$initialPath/',
        ]);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim();
        }
      } catch (_) {}

      try {
        final result = await Process.run('kdialog', [
          '--getexistingdirectory',
          initialPath ?? Platform.environment['HOME'] ?? '/',
          '--title', title ?? 'İndirme Klasörünü Seçin',
        ]);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim();
        }
      } catch (_) {}
    }

    // 3. Windows native fallback: PowerShell folder browser
    if (Platform.isWindows) {
      try {
        final psScript = '''
Add-Type -AssemblyName System.Windows.Forms
\$f = New-Object System.Windows.Forms.FolderBrowserDialog
\$f.Description = "${title ?? 'İndirme Klasörünü Seçin'}"
if (\$f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output \$f.SelectedPath
}
''';
        final result = await Process.run('powershell', ['-NoProfile', '-Command', psScript]);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim();
        }
      } catch (_) {}
    }

    return null;
  }
}
