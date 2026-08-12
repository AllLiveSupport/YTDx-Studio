import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/download_task.dart';
import '../theme/app_colors.dart';
import '../widgets/download_card.dart';
import '../widgets/history_card.dart';
import '../services/file_launcher.dart';
import '../services/i18n.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeTasks = appState.tasks.where((t) => t.status != DownloadStatus.completed).toList();
    final completedTasks = appState.completedTasks;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Path Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.tr('downloads_title'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      const SizedBox(width: 5),
                      Text(
                        '${I18n.tr('downloads_folder')} ${appState.settings.downloadPath}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Action Buttons
              Row(
                children: [
                  // Open Download Folder Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: Text(I18n.tr('downloads_btn_open_folder'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E2128) : const Color(0xFFE2E8F0),
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      FileLauncher.openFolder(appState.settings.downloadPath);
                    },
                  ),

                  if (activeTasks.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    // Cancel All Active Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.stop_circle_outlined, size: 16),
                      label: Text(I18n.tr('downloads_btn_cancel_all'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        appState.cancelAllTasks();
                      },
                    ),
                  ],

                  if (completedTasks.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    // Clear History Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.clear_all_rounded, size: 16),
                      label: Text(I18n.tr('downloads_btn_clear'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        appState.clearCompletedTasks();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 1. ACTIVE DOWNLOADS SECTION
          if (activeTasks.isNotEmpty) ...[
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 8),
                Text(
                  '${I18n.tr('downloads_active')} (${activeTasks.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeTasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = activeTasks[index];
                return DownloadCard(task: task);
              },
            ),
            const SizedBox(height: 28),
          ],

          // 2. COMPLETED DOWNLOADS HISTORY SECTION
          Text(
            '${I18n.tr('downloads_history')} (${completedTasks.length})',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 14),

          if (completedTasks.isEmpty && activeTasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_download_outlined,
                      size: 48,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      I18n.tr('downloads_empty_history'),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (completedTasks.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.86,
              ),
              itemCount: completedTasks.length,
              itemBuilder: (context, index) {
                final task = completedTasks[index];
                return HistoryCard(
                  task: task,
                  onRemove: () {
                    appState.deleteCompletedTask(task, deleteFromDisk: true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(I18n.tr('msg_file_deleted')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
