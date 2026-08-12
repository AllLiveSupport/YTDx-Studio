import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../services/i18n.dart';

class DownloadCard extends StatelessWidget {
  final DownloadTask task;

  const DownloadCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final percentText = task.status == DownloadStatus.queued
        ? I18n.tr('downloads_queued')
        : '${(task.progress * 100).toInt()}%';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 100,
                    height: 58,
                    child: task.video.thumbnail.isNotEmpty
                        ? Image.network(
                            task.video.thumbnail,
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, _, _) => Container(
                              color: isDark ? const Color(0xFF1E2026) : const Color(0xFFE2E8F0),
                              child: const Icon(Icons.download, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: isDark ? const Color(0xFF1E2026) : const Color(0xFFE2E8F0),
                            child: const Icon(Icons.download, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Channel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            task.video.channel,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (task.isAudio ? AppColors.greenMusic : AppColors.redVideo).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${task.format.toUpperCase()} ${task.quality.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: task.isAudio ? AppColors.greenMusic : AppColors.redVideo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Engine badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.engineUsed,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Control Buttons (Cancel / Status Icon)
                if (task.status == DownloadStatus.queued) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          I18n.tr('downloads_queued'),
                          style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => appState.cancelTask(task),
                    tooltip: I18n.tr('downloads_tooltip_dequeue'),
                  ),
                ] else if (task.isRunning) ...[
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                    onPressed: () => appState.cancelTask(task),
                    tooltip: I18n.tr('downloads_tooltip_cancel'),
                  ),
                ] else if (task.status == DownloadStatus.completed) ...[
                  const Icon(Icons.check_circle_rounded, color: AppColors.greenMusic, size: 24),
                ] else if (task.status == DownloadStatus.failed) ...[
                  IconButton(
                    icon: const Icon(Icons.error_outline_rounded, color: AppColors.redVideo, size: 22),
                    onPressed: () => appState.cancelTask(task),
                    tooltip: I18n.tr('downloads_tooltip_remove'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar & Percentage
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.status == DownloadStatus.queued
                          ? null
                          : (task.progress > 0 ? task.progress : null),
                      minHeight: 5,
                      backgroundColor: isDark ? const Color(0xFF282B33) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.status == DownloadStatus.queued
                            ? Colors.amber
                            : (task.isAudio ? AppColors.greenMusic : AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  percentText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Size, Speed, ETA Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${I18n.tr('downloads_size')} ${task.sizeInfo}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                Text(
                  task.status == DownloadStatus.queued
                      ? I18n.tr('downloads_waiting')
                      : '${I18n.tr('downloads_speed')} ${task.speed}  •  ${I18n.tr('downloads_eta_full')} ${task.eta}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
