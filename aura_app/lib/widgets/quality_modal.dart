import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../theme/app_colors.dart';
import '../services/i18n.dart';

class QualityModal extends StatefulWidget {
  final VideoItem video;
  final bool initialIsAudio;
  final Function(String format, String quality) onConfirm;

  const QualityModal({
    super.key,
    required this.video,
    this.initialIsAudio = false,
    required this.onConfirm,
  });

  @override
  State<QualityModal> createState() => _QualityModalState();
}

class _QualityModalState extends State<QualityModal> {
  late bool _isAudio;
  String _selectedVideoFormat = 'mp4'; // 'mp4' or 'ts'

  @override
  void initState() {
    super.initState();
    _isAudio = widget.initialIsAudio;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final audioOptions = [
      {
        'format': 'mp3',
        'quality': '320k',
        'title': I18n.tr('modal_mp3_title'),
        'desc': I18n.tr('modal_mp3_sub'),
        'badge': I18n.tr('modal_badge_recommended'),
        'color': AppColors.greenMusic,
      },
      {
        'format': 'm4a',
        'quality': '256k',
        'title': I18n.tr('modal_m4a_title'),
        'desc': I18n.tr('modal_m4a_sub'),
        'badge': I18n.tr('modal_badge_original'),
        'color': Colors.cyanAccent,
      },
    ];

    final isTs = _selectedVideoFormat == 'ts';
    final videoOptions = [
      {
        'format': _selectedVideoFormat,
        'quality': 'auto',
        'title': isTs ? 'Auto TS (En İyi)' : I18n.tr('modal_auto_best'),
        'desc': isTs ? 'En yüksek çözünürlükte MPEG Transport Stream (.ts)' : I18n.tr('modal_auto_best_sub'),
        'badge': isTs ? 'TS AUTO' : I18n.tr('modal_badge_recommended'),
        'color': isTs ? Colors.orangeAccent : Colors.amber,
      },
      {
        'format': _selectedVideoFormat,
        'quality': '4320p',
        'title': isTs ? '8K TS (Ultra HD)' : I18n.tr('quality_8k_title'),
        'desc': isTs ? '4320p MPEG Transport Stream (.ts)' : I18n.tr('quality_8k_desc'),
        'badge': isTs ? '8K TS' : '8K',
        'color': Colors.purpleAccent,
      },
      {
        'format': _selectedVideoFormat,
        'quality': '2160p',
        'title': isTs ? '4K TS (Ultra HD)' : I18n.tr('quality_4k_title'),
        'desc': isTs ? '2160p MPEG Transport Stream (.ts)' : I18n.tr('quality_4k_desc'),
        'badge': isTs ? '4K TS' : '4K',
        'color': AppColors.redVideo,
      },
      {
        'format': _selectedVideoFormat,
        'quality': '1440p',
        'title': isTs ? '2K TS (QHD)' : I18n.tr('quality_2k_title'),
        'desc': isTs ? '1440p MPEG Transport Stream (.ts)' : I18n.tr('quality_2k_desc'),
        'badge': isTs ? '2K TS' : '2K',
        'color': AppColors.primaryBlue,
      },
      {
        'format': _selectedVideoFormat,
        'quality': '1080p',
        'title': isTs ? '1080p TS (Full HD)' : I18n.tr('quality_1080p_title'),
        'desc': isTs ? '1080p MPEG Transport Stream (.ts)' : I18n.tr('quality_1080p_desc'),
        'badge': isTs ? '1080p TS' : '1080p',
        'color': Colors.tealAccent,
      },
      {
        'format': _selectedVideoFormat,
        'quality': '720p',
        'title': isTs ? '720p TS (HD)' : I18n.tr('quality_720p_title'),
        'desc': isTs ? '720p MPEG Transport Stream (.ts)' : I18n.tr('quality_720p_desc'),
        'badge': isTs ? '720p TS' : null,
        'color': Colors.grey,
      },
      {
        'format': _selectedVideoFormat,
        'quality': '480p',
        'title': isTs ? '480p TS (SD)' : I18n.tr('quality_480p_title'),
        'desc': isTs ? '480p MPEG Transport Stream (.ts)' : I18n.tr('quality_480p_desc'),
        'badge': isTs ? '480p TS' : null,
        'color': Colors.grey,
      },
      {
        'format': _selectedVideoFormat,
        'quality': '360p',
        'title': isTs ? '360p TS' : I18n.tr('quality_360p_title'),
        'desc': isTs ? '360p MPEG Transport Stream (.ts)' : I18n.tr('quality_360p_desc'),
        'badge': isTs ? '360p TS' : null,
        'color': Colors.grey,
      },
    ];

    final options = _isAudio ? audioOptions : videoOptions;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.video.thumbnail.isNotEmpty
                      ? Image.network(
                          widget.video.thumbnail,
                          width: 48,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 48,
                            height: 36,
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.movie_creation_outlined, size: 20, color: Colors.white70),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 36,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.movie_creation_outlined, size: 20, color: Colors.white70),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAudio ? I18n.tr('modal_title_audio') : I18n.tr('modal_title_video'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab Selector: [ 🎬 Video ]  [ 🎵 Müzik ]
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2129) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isAudio = false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isAudio ? AppColors.redVideo : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isAudio
                              ? [BoxShadow(color: AppColors.redVideo.withValues(alpha: 0.3), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              I18n.tr('modal_video_tab'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isAudio = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isAudio ? AppColors.greenMusic : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isAudio
                              ? [BoxShadow(color: AppColors.greenMusic.withValues(alpha: 0.3), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.music_note_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              I18n.tr('modal_audio_tab'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Format Switcher (Video Tab: MP4 vs TS)
            if (!_isAudio) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF191C23) : const Color(0xFFE8EDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder.withValues(alpha: 0.6) : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedVideoFormat = 'mp4'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedVideoFormat == 'mp4'
                                ? (isDark ? const Color(0xFF2B313E) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedVideoFormat == 'mp4'
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_file_outlined,
                                size: 15,
                                color: _selectedVideoFormat == 'mp4' ? AppColors.redVideo : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MP4 (Standart)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedVideoFormat == 'mp4' ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedVideoFormat == 'mp4' ? (isDark ? Colors.white : AppColors.redVideo) : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedVideoFormat = 'ts'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedVideoFormat == 'ts'
                                ? (isDark ? const Color(0xFF2B313E) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedVideoFormat == 'ts'
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.live_tv_rounded,
                                size: 15,
                                color: _selectedVideoFormat == 'ts' ? Colors.orangeAccent : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TS (MPEG-TS)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedVideoFormat == 'ts' ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedVideoFormat == 'ts' ? (isDark ? Colors.white : Colors.orange.shade800) : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Scrollable Quality Options List
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final opt = options[index];
                  final badge = opt['badge'] as String?;
                  final color = (opt['color'] as Color?) ?? AppColors.primaryBlue;

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onConfirm(opt['format'] as String, opt['quality'] as String);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2129) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isAudio ? Icons.music_note_rounded : Icons.play_circle_outline_rounded,
                            color: color,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        opt['title'] as String,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ),
                                    if (badge != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          badge,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
