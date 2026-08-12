import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../services/file_launcher.dart';
import '../services/i18n.dart';

class HistoryCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onRemove;

  const HistoryCard({
    super.key,
    required this.task,
    required this.onRemove,
  });

  String? _resolveFilePath() {
    if (task.filePath != null && File(task.filePath!).existsSync()) {
      return task.filePath;
    }
    try {
      final dir = Directory(task.outputPath);
      if (dir.existsSync()) {
        final cleanTitle = task.video.title
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .toLowerCase();
        for (var f in dir.listSync(recursive: true).whereType<File>()) {
          final name = f.uri.pathSegments.last.toLowerCase();
          if (name.contains(cleanTitle) || cleanTitle.contains(name.replaceAll(RegExp(r'\.[a-z0-9]+$'), ''))) {
            task.filePath = f.path;
            return f.path;
          }
        }
      }
    } catch (_) {}
    return task.filePath;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAudio = task.isAudio;
    final resolvedPath = _resolveFilePath();
    final hasFile = resolvedPath != null && File(resolvedPath).existsSync();
    final player = context.watch<PlayerProvider>();
    final isThisPlaying = player.currentTask?.id == task.id && player.isPlaying;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isThisPlaying
                ? AppColors.primaryBlue
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isThisPlaying ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: task.video.thumbnail.isNotEmpty
                          ? Image.network(
                              task.video.thumbnail,
                              fit: BoxFit.cover,
                              cacheWidth: 320,
                              errorBuilder: (_, _, _) => Container(
                                color: isDark ? const Color(0xFF1E2129) : const Color(0xFFE2E8F0),
                                child: Icon(
                                  isAudio ? Icons.music_note : Icons.videocam,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  size: 36,
                                ),
                              ),
                            )
                          : Container(
                              color: isDark ? const Color(0xFF1E2129) : const Color(0xFFE2E8F0),
                              child: Icon(
                                isAudio ? Icons.music_note : Icons.videocam,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                size: 36,
                              ),
                            ),
                    ),

                    // Format Badge (Top Left)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: (isAudio ? AppColors.greenMusic : AppColors.redVideo).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '${task.format.toUpperCase()} ${task.quality.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Quick Play Overlay (Only for Audio files)
                    if (hasFile && isAudio)
                      Center(
                        child: InkWell(
                          onTap: () {
                            if (isThisPlaying) {
                              player.togglePlayPause();
                            } else {
                              player.playTask(task);
                            }
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isThisPlaying
                                  ? AppColors.primaryBlue
                                  : Colors.black.withValues(alpha: 0.65),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                            ),
                            child: Icon(
                              isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),

                    // Duration Badge (Bottom Right)
                    if (task.video.duration.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.video.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Video Title
              Text(
                task.video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 4),

              // Channel & File Size
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.video.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  if (task.sizeInfo.isNotEmpty)
                    Text(
                      task.sizeInfo.split('/').last.trim(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Action Buttons
              Row(
                children: [
                  // If Audio: Show In-App Play Button. If Video: Show Open Video Player Button
                  if (isAudio) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
                        label: Text(
                          isThisPlaying ? I18n.tr('btn_pause') : I18n.tr('btn_play'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isThisPlaying ? AppColors.greenMusic : AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final path = _resolveFilePath();
                          if (path != null && File(path).existsSync()) {
                            task.filePath = path;
                            if (isThisPlaying) {
                              player.togglePlayPause();
                            } else {
                              player.playTask(task);
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(I18n.tr('msg_file_not_found'))),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 5),

                    // External Player Button for Audio
                    InkWell(
                      onTap: () {
                        final path = _resolveFilePath();
                        if (path != null && File(path).existsSync()) {
                          FileLauncher.openFile(path);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF22252D) : const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.launch_rounded,
                          size: 15,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ] else ...[
                    // For Video: Direct "Videoyu Aç" button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                        label: Text(
                          I18n.tr('btn_open_video'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.redVideo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final path = _resolveFilePath();
                          if (path != null && File(path).existsSync()) {
                            FileLauncher.openFile(path);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(I18n.tr('msg_video_not_found'))),
                            );
                          }
                        },
                      ),
                    ),
                  ],

                  const SizedBox(width: 5),

                  // Open Folder Button
                  InkWell(
                    onTap: () {
                      final path = _resolveFilePath();
                      if (path != null && File(path).existsSync()) {
                        FileLauncher.openFolder(path);
                      } else if (task.outputPath.isNotEmpty) {
                        FileLauncher.openFolder(task.outputPath);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF22252D) : const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        size: 15,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 5),

                  // Delete/Remove Button
                  InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF22252D) : const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: Colors.red.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
