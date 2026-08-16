import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/video_item.dart';
import '../theme/app_colors.dart';
import '../services/native_folder_picker.dart';
import '../services/backend_locator.dart';
import '../services/i18n.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  bool _isLoading = false;
  List<VideoItem> _playlistVideos = [];
  String _playlistTitle = '';
  final Set<String> _selectedVideoIds = {};
  String _filterQuery = '';

  // Batch download presets
  String _selectedFormat = 'mp3'; // 'mp3', 'mp4', 'm4a'
  String _selectedQuality = '320k'; // '320k', '1080p', 'auto'
  String? _customOutputPath;
  bool _createSubfolder = true;

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() {
      setState(() {
        _filterQuery = _filterController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _playlistVideos = [];
      _selectedVideoIds.clear();
      _playlistTitle = '';
      _filterQuery = '';
      _filterController.clear();
    });

    try {
      final pythonExe = BackendLocator.findPython();
      final script = '''
import sys
import json
import yt_dlp

url = "$url"
ydl_opts = {
    'quiet': True,
    'extract_flat': True,
    'skip_download': True,
}
try:
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        entries = info.get('entries', [])
        title = info.get('title', 'YouTube Playlist')
        results = []
        for e in entries:
            if not e:
                continue
            dur_sec = e.get('duration') or 0
            m, s = divmod(dur_sec, 60)
            h, m = divmod(m, 60)
            dur_str = f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"
            results.append({
                'id': e.get('id', ''),
                'title': e.get('title', 'Untitled Video'),
                'author': e.get('uploader') or e.get('channel', 'YouTube Artist'),
                'duration': dur_str,
                'thumbnailUrl': f"https://i.ytimg.com/vi/{e.get('id', '')}/hqdefault.jpg"
            })
        print(json.dumps({'title': title, 'videos': results}))
except Exception as ex:
    print(json.dumps({'error': str(ex), 'videos': []}))
''';

      final res = await Process.run(pythonExe, ['-c', script]);
      if (res.exitCode == 0) {
        final data = jsonDecode(res.stdout.toString().trim());
        final title = data['title'] ?? 'YouTube Playlist';
        final rawVideos = data['videos'] as List? ?? [];

        final List<VideoItem> videos = rawVideos.map<VideoItem>((v) {
          final vidId = v['id'] ?? '';
          return VideoItem(
            id: vidId,
            title: v['title'] ?? '',
            url: 'https://www.youtube.com/watch?v=$vidId',
            channel: v['channel'] ?? v['author'] ?? '',
            duration: v['duration'] ?? '',
            thumbnail: v['thumbnailUrl'] ?? v['thumbnail'] ?? 'https://i.ytimg.com/vi/$vidId/hqdefault.jpg',
          );
        }).toList();

        setState(() {
          _playlistTitle = title;
          _playlistVideos = videos;
          _selectedVideoIds.addAll(videos.map((e) => e.id));
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist yüklenirken bir hata oluştu.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startBatchDownload(AppState appState) {
    if (_selectedVideoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir video seçin!')),
      );
      return;
    }

    final isAudio = _selectedFormat == 'mp3' || _selectedFormat == 'm4a' || _selectedFormat == 'flac';
    final selectedItems = _playlistVideos.where((v) => _selectedVideoIds.contains(v.id)).toList();

    String finalPath = _customOutputPath ?? appState.settings.downloadPath;
    if (_createSubfolder && _playlistTitle.isNotEmpty) {
      final safeTitle = _playlistTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      finalPath = '$finalPath/$safeTitle';
    }

    final result = appState.startBatchDownload(
      selectedVideos: selectedItems,
      isAudio: isAudio,
      format: _selectedFormat,
      quality: _selectedQuality,
      outputPath: finalPath,
    );

    if (result.skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.queued} yeni dosya kuyruğa eklendi. ${result.skipped} adet daha önce indirilmiş dosya atlandı.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.queued} parça indirme kuyruğuna eklendi!'),
        ),
      );
    }

    // Switch to Downloads tab to see live queue
    appState.setTabIndex(2);
  }

  List<VideoItem> get _filteredVideos {
    if (_filterQuery.isEmpty) return _playlistVideos;
    return _playlistVideos.where((v) {
      return v.title.toLowerCase().contains(_filterQuery) ||
          v.channel.toLowerCase().contains(_filterQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPath = _customOutputPath ?? appState.settings.downloadPath;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.purpleAccent, AppColors.primaryBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        I18n.tr('playlist_title'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    I18n.tr('playlist_subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Playlist URL Input Pill Bar (Glassmorphic & Gradient)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    onSubmitted: (_) => _fetchPlaylist(),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: I18n.tr('playlist_placeholder'),
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_urlController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    onPressed: () {
                      _urlController.clear();
                      setState(() {});
                    },
                  ),
                // Paste button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2129) : const Color(0xFFEBF1F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    tooltip: I18n.tr('home_paste_btn'),
                    icon: const Icon(Icons.content_paste_rounded, size: 17, color: AppColors.primaryBlue),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _urlController.text = data!.text!;
                        _fetchPlaylist();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // Fetch button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isLoading ? I18n.tr('playlist_fetching') : I18n.tr('playlist_fetch_btn'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _fetchPlaylist,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Content Area: Empty State vs Loaded Playlist
          if (_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 80),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text(
                    I18n.tr('playlist_scanning'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'YouTube çalma listesi verileri taranıyor...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else if (_playlistVideos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      size: 36,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    I18n.tr('playlist_not_loaded'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    I18n.tr('playlist_paste_hint'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            // Two Column Layout: Video Grid (Left) + Batch Control Panel (Right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Playlist Hero & Track List
                Expanded(
                  flex: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Playlist Overview Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1B1E29), const Color(0xFF14161D)]
                                : [const Color(0xFFF1F5FB), const Color(0xFFE5EEF9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Playlist Cover Badge
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: _playlistVideos.isNotEmpty
                                        ? Image.network(
                                            _playlistVideos.first.thumbnail,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Container(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                              child: const Icon(Icons.music_note, color: AppColors.primaryBlue, size: 32),
                                            ),
                                          )
                                        : Container(
                                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                            child: const Icon(Icons.music_note, color: AppColors.primaryBlue, size: 32),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _playlistTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _InfoBadge(
                                            icon: Icons.video_library_rounded,
                                            text: '${_playlistVideos.length} Video / Şarkı',
                                            color: AppColors.primaryBlue,
                                          ),
                                          _InfoBadge(
                                            icon: Icons.check_circle_rounded,
                                            text: '${_selectedVideoIds.length} Seçildi',
                                            color: AppColors.greenMusic,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, thickness: 1, color: Colors.white10),
                            const SizedBox(height: 14),

                            // Filter Box & Quick Selection Buttons
                            Row(
                              children: [
                                // Local Search inside Playlist
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF101217) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.search, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _filterController,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Liste içinde ara...',
                                              hintStyle: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                              ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        if (_filterQuery.isNotEmpty)
                                          GestureDetector(
                                            onTap: () => _filterController.clear(),
                                            child: const Icon(Icons.close, size: 14),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Select All Button
                                _QuickSelectButton(
                                  label: I18n.tr('playlist_select_all'),
                                  icon: Icons.done_all_rounded,
                                  color: AppColors.primaryBlue,
                                  onTap: () {
                                    setState(() {
                                      _selectedVideoIds.addAll(_playlistVideos.map((v) => v.id));
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                // Deselect All Button
                                _QuickSelectButton(
                                  label: I18n.tr('playlist_deselect_all'),
                                  icon: Icons.remove_done_rounded,
                                  color: Colors.redAccent,
                                  onTap: () {
                                    setState(() {
                                      _selectedVideoIds.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Playlist Tracks List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredVideos.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final video = _filteredVideos[index];
                          final isSelected = _selectedVideoIds.contains(video.id);

                          return RepaintBoundary(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedVideoIds.remove(video.id);
                                  } else {
                                    _selectedVideoIds.add(video.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF1E2435) : const Color(0xFFE9F2FF))
                                      : (isDark ? AppColors.darkCard : AppColors.lightCard),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryBlue.withValues(alpha: 0.8)
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    width: isSelected ? 1.4 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  children: [
                                    // Track Index
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '#${index + 1}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppColors.primaryBlue
                                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                        ),
                                      ),
                                    ),

                                    // Custom Checkbox
                                    Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primaryBlue
                                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                                          : null,
                                    ),

                                    // Thumbnail with Duration Overlay
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            video.thumbnail,
                                            width: 80,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            cacheWidth: 160,
                                            errorBuilder: (_, _, _) => Container(
                                              width: 80,
                                              height: 48,
                                              color: Colors.black26,
                                              child: const Icon(Icons.movie_creation_outlined, size: 20),
                                            ),
                                          ),
                                          if (video.duration.isNotEmpty)
                                            Positioned(
                                              bottom: 3,
                                              right: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.8),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  video.duration,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(width: 14),

                                  // Title & Channel Metadata
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          video.title,
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
                                            Icon(
                                              Icons.person_rounded,
                                              size: 13,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                video.channel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11.5,
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
                          ));
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Right Column: Batch Control Center Panel (Glassmorphic)
                Expanded(
                  flex: 36,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              I18n.tr('playlist_panel_title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Format Selector
                        Text(
                          'Format',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _FormatChip(
                              label: 'MP3 (Müzik)',
                              icon: Icons.music_note_rounded,
                              isSelected: _selectedFormat == 'mp3',
                              color: AppColors.greenMusic,
                              onTap: () => setState(() {
                                _selectedFormat = 'mp3';
                                _selectedQuality = '320k';
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FormatChip(
                              label: 'MP4 (Video)',
                              icon: Icons.videocam_rounded,
                              isSelected: _selectedFormat == 'mp4',
                              color: AppColors.redVideo,
                              onTap: () => setState(() {
                                _selectedFormat = 'mp4';
                                _selectedQuality = 'auto';
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FormatChip(
                              label: 'M4A (Müzik)',
                              icon: Icons.graphic_eq_rounded,
                              isSelected: _selectedFormat == 'm4a',
                              color: Colors.cyanAccent.shade700,
                              onTap: () => setState(() {
                                _selectedFormat = 'm4a';
                                _selectedQuality = '256k';
                              }),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Quality Selector
                        Text(
                          (_selectedFormat == 'mp4')
                              ? I18n.tr('modal_title_video')
                              : I18n.tr('modal_title_audio'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14161C) : const Color(0xFFF1F4F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedQuality,
                              dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                              items: (_selectedFormat == 'mp4')
                                  ? const [
                                      DropdownMenuItem(value: 'auto', child: Text('otomatik (En Yüksek Kalite)')),
                                      DropdownMenuItem(value: '4320p', child: Text('4320p (8K Ultra HD)')),
                                      DropdownMenuItem(value: '2160p', child: Text('2160p (4K Ultra HD)')),
                                      DropdownMenuItem(value: '1440p', child: Text('1440p (2K QHD)')),
                                      DropdownMenuItem(value: '1080p', child: Text('1080p Full HD')),
                                      DropdownMenuItem(value: '720p', child: Text('720p HD')),
                                      DropdownMenuItem(value: '480p', child: Text('480p SD')),
                                      DropdownMenuItem(value: '360p', child: Text('360p')),
                                    ]
                                  : (_selectedFormat == 'm4a')
                                      ? const [
                                          DropdownMenuItem(value: '256k', child: Text('En Yüksek Kalite (Tavsiye Edilen)')),
                                          DropdownMenuItem(value: '128k', child: Text('Düşük / Hızlı Kalite')),
                                        ]
                                      : const [
                                          DropdownMenuItem(value: '320k', child: Text('En Yüksek Kalite (Tavsiye Edilen)')),
                                          DropdownMenuItem(value: '128k', child: Text('Düşük / Hızlı Kalite')),
                                        ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedQuality = val);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Output Folder Picker
                        Text(
                          I18n.tr('settings_download_path'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14161C) : const Color(0xFFF1F4F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_rounded, size: 18, color: AppColors.primaryBlue),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  currentPath,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await NativeFolderPicker.pickDirectory(
                                    initialPath: currentPath,
                                    title: 'Playlist İndirme Klasörünü Seçin',
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _customOutputPath = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    I18n.tr('settings_browse'),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Subfolder toggle switch
                        InkWell(
                          onTap: () => setState(() => _createSubfolder = !_createSubfolder),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _createSubfolder,
                                    activeColor: AppColors.primaryBlue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) => setState(() => _createSubfolder = val ?? true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    I18n.tr('playlist_subfolder'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Big Glowing Batch Download Button
                        Builder(
                          builder: (context) {
                            final isAudioFormat = _selectedFormat == 'mp3' || _selectedFormat == 'm4a';
                            final List<Color> gradientColors = isAudioFormat
                                ? (_selectedFormat == 'mp3'
                                    ? [AppColors.greenMusic, const Color(0xFF00BFA5)]
                                    : [const Color(0xFF00ACC1), AppColors.primaryBlue])
                                : [AppColors.redVideo, AppColors.purpleAccent];
                            final Color glowColor = isAudioFormat
                                ? (_selectedFormat == 'mp3' ? AppColors.greenMusic : Colors.cyanAccent)
                                : AppColors.primaryBlue;

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: glowColor.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.cloud_download_rounded, size: 20, color: Colors.white),
                                label: Text(
                                  '${isAudioFormat ? I18n.tr('playlist_download_audio') : I18n.tr('playlist_download_video')} (${_selectedVideoIds.length})',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _selectedVideoIds.isEmpty ? null : () => _startBatchDownload(appState),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.25),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSelectButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickSelectButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
