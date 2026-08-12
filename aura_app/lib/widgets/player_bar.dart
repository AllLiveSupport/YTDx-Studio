import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../services/file_launcher.dart';

class PlayerBar extends StatefulWidget {
  const PlayerBar({super.key});

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  double? _dragSec;

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!player.isVisible || player.currentTask == null) {
      return const SizedBox.shrink();
    }

    final task = player.currentTask!;
    final pos = player.position;
    final dur = player.duration;
    final totalSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
    final displaySec = (_dragSec ?? pos.inSeconds.toDouble()).clamp(0.0, totalSec);

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14161C) : const Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Left Section: Track Info & Artwork
          Expanded(
            flex: 30,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: task.video.thumbnail.isNotEmpty
                        ? Image.network(
                            task.video.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.primaryBlue.withValues(alpha: 0.2),
                              child: const Icon(Icons.music_note, color: AppColors.primaryBlue),
                            ),
                          )
                        : Container(
                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                            child: const Icon(Icons.music_note, color: AppColors.primaryBlue),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (task.isAudio ? AppColors.greenMusic : AppColors.redVideo).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.format.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: task.isAudio ? AppColors.greenMusic : AppColors.redVideo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Center Section: Playback Controls & Seek Bar
          Expanded(
            flex: 46,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Control Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Loop Toggle
                    IconButton(
                      icon: Icon(
                        Icons.repeat_rounded,
                        size: 18,
                        color: player.isLooping
                            ? AppColors.primaryBlue
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      tooltip: 'Döngü',
                      onPressed: player.toggleLoop,
                    ),
                    const SizedBox(width: 8),

                    // Play/Pause Big Button
                    InkWell(
                      onTap: player.togglePlayPause,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Stop Button
                    IconButton(
                      icon: Icon(
                        Icons.stop_rounded,
                        size: 20,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      tooltip: 'Durdur',
                      onPressed: player.stop,
                    ),
                  ],
                ),

                // Seek Progress Bar + Timestamps
                Row(
                  children: [
                    Text(
                      _formatDuration(Duration(seconds: displaySec.toInt())),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTrackColor: AppColors.primaryBlue,
                          inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          thumbColor: AppColors.primaryBlue,
                        ),
                        child: Slider(
                          value: displaySec,
                          min: 0.0,
                          max: totalSec,
                          onChanged: (val) {
                            setState(() => _dragSec = val);
                          },
                          onChangeEnd: (val) {
                            player.seek(Duration(seconds: val.toInt()));
                            setState(() => _dragSec = null);
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(dur),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Right Section: Volume & Quick External Actions
          Expanded(
            flex: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Volume Icon
                Icon(
                  player.volume == 0
                      ? Icons.volume_off_rounded
                      : (player.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                  size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 4),

                // Volume Slider
                SizedBox(
                  width: 80,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                      activeTrackColor: AppColors.primaryBlue,
                      inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      thumbColor: AppColors.primaryBlue,
                    ),
                    child: Slider(
                      value: player.volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) => player.setVolume(val),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Open Folder Button
                IconButton(
                  icon: Icon(
                    Icons.folder_open_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  tooltip: 'Klasörde Aç',
                  onPressed: () {
                    if (task.filePath != null) {
                      FileLauncher.openFolder(task.filePath!);
                    } else {
                      FileLauncher.openFolder(task.outputPath);
                    }
                  },
                ),

                // Close Player Button
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  tooltip: 'Oynatıcıyı Kapat',
                  onPressed: player.closePlayer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
