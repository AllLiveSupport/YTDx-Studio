import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/download_task.dart';
import '../theme/app_colors.dart';
import '../services/file_launcher.dart';

class TaskLogDialog extends StatefulWidget {
  final DownloadTask task;

  const TaskLogDialog({super.key, required this.task});

  static void show(BuildContext context, DownloadTask task) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => TaskLogDialog(task: task),
    );
  }

  @override
  State<TaskLogDialog> createState() => _TaskLogDialogState();
}

class _TaskLogDialogState extends State<TaskLogDialog> {
  String _selectedFilter = 'all'; // 'all', 'steps', 'errors', 'warnings'
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<TaskLogEntry> _getFilteredLogs() {
    final all = widget.task.logs;
    if (_selectedFilter == 'steps') {
      return all.where((l) => l.level == LogLevel.step || l.level == LogLevel.success).toList();
    } else if (_selectedFilter == 'errors') {
      return all.where((l) => l.level == LogLevel.error).toList();
    } else if (_selectedFilter == 'warnings') {
      return all.where((l) => l.level == LogLevel.warning).toList();
    }
    return all;
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.step:
        return const Color(0xFF60A5FA); // Blue
      case LogLevel.info:
        return const Color(0xFF94A3B8); // Slate/Grey
      case LogLevel.warning:
        return const Color(0xFFFBBF24); // Amber
      case LogLevel.error:
        return const Color(0xFFF87171); // Red
      case LogLevel.success:
        return const Color(0xFF34D399); // Emerald
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.step:
        return Icons.play_arrow_rounded;
      case LogLevel.info:
        return Icons.info_outline_rounded;
      case LogLevel.warning:
        return Icons.warning_amber_rounded;
      case LogLevel.error:
        return Icons.error_outline_rounded;
      case LogLevel.success:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final task = widget.task;
    final filteredLogs = _getFilteredLogs();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13161D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Container(
        width: 720,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: task.video.thumbnail.isNotEmpty
                      ? Image.network(
                          task.video.thumbnail,
                          width: 64,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 64,
                            height: 48,
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.download, color: Colors.white70),
                          ),
                        )
                      : Container(
                          width: 64,
                          height: 48,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.download, color: Colors.white70),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Canlı İşlem ve Hata Günlüğü',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live animated indicator if running
                          if (task.isRunning) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'CANLI',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Kapat',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Metrics Row: Badges & Statistics
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status Badge
                  _buildMetricBadge(
                    label: task.status.name.toUpperCase(),
                    color: task.status == DownloadStatus.completed
                        ? const Color(0xFF10B981)
                        : (task.status == DownloadStatus.failed ? Colors.redAccent : AppColors.primaryBlue),
                    icon: task.status == DownloadStatus.completed
                        ? Icons.check_circle_rounded
                        : (task.status == DownloadStatus.failed ? Icons.error_rounded : Icons.sync_rounded),
                  ),
                  const SizedBox(width: 8),

                  // Engine Badge
                  _buildMetricBadge(
                    label: task.engineUsed,
                    color: Colors.cyanAccent,
                    icon: Icons.electric_bolt_rounded,
                  ),
                  const SizedBox(width: 8),

                  // Format & Quality Badge
                  _buildMetricBadge(
                    label: '${task.format.toUpperCase()} • ${task.quality.toUpperCase()}',
                    color: task.isAudio ? AppColors.greenMusic : AppColors.redVideo,
                    icon: task.isAudio ? Icons.music_note_rounded : Icons.videocam_rounded,
                  ),
                  const SizedBox(width: 8),

                  // Step count
                  _buildMetricBadge(
                    label: '${task.logs.length} İşlem Kaydı',
                    color: Colors.blueGrey,
                    icon: Icons.list_alt_rounded,
                  ),

                  if (task.errorCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildMetricBadge(
                      label: '${task.errorCount} Hata',
                      color: Colors.redAccent,
                      icon: Icons.report_problem_rounded,
                    ),
                  ],

                  if (task.warningCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildMetricBadge(
                      label: '${task.warningCount} Uyarı',
                      color: Colors.amber,
                      icon: Icons.warning_rounded,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Filter Chips Row
            Row(
              children: [
                _buildFilterChip('all', 'Tümü (${task.logs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('steps', 'Adımlar (${task.stepCount})'),
                const SizedBox(width: 8),
                _buildFilterChip('warnings', 'Uyarılar (${task.warningCount})'),
                const SizedBox(width: 8),
                _buildFilterChip('errors', 'Hatalar (${task.errorCount})'),
                const Spacer(),
                // Copy button
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Panoya Kopyala', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: task.allLogsText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tüm işlem ve hata günlükleri panoya kopyalandı!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Live Log Console Box
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF090B10) : const Color(0xFF1E2128),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Text(
                          'Bu filtreye uygun günlük kaydı bulunamadı.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final logEntry = filteredLogs[index];
                          final color = _getLevelColor(logEntry.level);
                          final icon = _getLevelIcon(logEntry.level);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Time stamp
                                Text(
                                  logEntry.timeFormatted,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Icon
                                Icon(icon, size: 14, color: color),
                                const SizedBox(width: 8),

                                // Log message
                                Expanded(
                                  child: SelectableText(
                                    logEntry.message,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      height: 1.35,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Actions
            Row(
              children: [
                if (task.filePath != null && File(task.filePath!).existsSync()) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Dosyayı Klasörde Göster', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E2128) : const Color(0xFFE2E8F0),
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      FileLauncher.openFolder(task.filePath!);
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBadge({required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue
              : (isDark ? const Color(0xFF1E2129) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
