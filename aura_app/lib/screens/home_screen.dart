import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/video_card.dart';
import '../services/i18n.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _topics = [
    {
      'key': 'general',
      'icon': Icons.whatshot_rounded,
      'color': const Color(0xFFFF5252),
    },
    {
      'key': 'music',
      'icon': Icons.music_note_rounded,
      'color': AppColors.greenMusic,
    },
    {
      'key': 'gaming',
      'icon': Icons.sports_esports_rounded,
      'color': AppColors.purpleAccent,
    },
    {
      'key': 'movies',
      'icon': Icons.movie_creation_rounded,
      'color': const Color(0xFFFF4081),
    },
    {
      'key': 'sports',
      'icon': Icons.sports_soccer_rounded,
      'color': const Color(0xFFFFAB00),
    },
    {
      'key': 'tech',
      'icon': Icons.memory_rounded,
      'color': const Color(0xFF00E5FF),
    },
    {
      'key': 'news',
      'icon': Icons.newspaper_rounded,
      'color': const Color(0xFF448AFF),
    },
  ];

  final List<Map<String, String>> _regions = [
    {'code': 'TR', 'name': 'Türkiye', 'flag': '🇹🇷'},
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'DE', 'name': 'Deutschland', 'flag': '🇩🇪'},
    {'code': 'FR', 'name': 'France', 'flag': '🇫🇷'},
    {'code': 'RU', 'name': 'Россия', 'flag': '🇷🇺'},
    {'code': 'JP', 'name': '日本 (Japan)', 'flag': '🇯🇵'},
    {'code': 'KR', 'name': '대한민국 (Korea)', 'flag': '🇰🇷'},
    {'code': 'BR', 'name': 'Brasil', 'flag': '🇧🇷'},
    {'code': 'AZ', 'name': 'Azərbaycan', 'flag': '🇦🇿'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchOrPaste(AppState appState) {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;

    if (text.contains('playlist?list=')) {
      appState.fetchPlaylist(text);
      appState.setTabIndex(3); // Switch to Playlists
    } else {
      appState.search(text);
      appState.setTabIndex(1); // Switch to Search
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTopic = appState.settings.trendingTopic;
    final currentRegion = appState.settings.region;

    final currentRegionObj = _regions.firstWhere(
      (r) => r['code'] == currentRegion,
      orElse: () => {'code': currentRegion, 'name': currentRegion, 'flag': '🌐'},
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Center Welcome Hero Section
          Center(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  I18n.tr('home_welcome'),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  I18n.tr('home_subtitle'),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 22),

                // Large Central Search / Paste Bar
                Container(
                  width: 620,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 18),
                      const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: I18n.tr('home_search_placeholder'),
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _handleSearchOrPaste(appState),
                        ),
                      ),

                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),

                      // Paste from Clipboard Button
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B1E26) : const Color(0xFFEBF1F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.paste_rounded, size: 17),
                          color: AppColors.primaryBlue,
                          tooltip: I18n.tr('home_paste_btn'),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data != null && data.text != null) {
                              _searchController.text = data.text!;
                              _handleSearchOrPaste(appState);
                            }
                          },
                        ),
                      ),

                      // Search Action Button
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryBlue, AppColors.purpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          tooltip: I18n.tr('nav_search'),
                          onPressed: () => _handleSearchOrPaste(appState),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Quick Category Switcher Bar (Responsive Wrap)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: _topics.map((item) {
                    final key = item['key'] as String;
                    final icon = item['icon'] as IconData;
                    final color = item['color'] as Color;
                    final isSelected = currentTopic == key;

                    return InkWell(
                      onTap: () {
                        if (!isSelected) {
                          appState.setTrendingTopic(key);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isSelected
                              ? color
                              : (isDark ? AppColors.darkCard : AppColors.lightCard),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: isSelected ? 1.4 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              I18n.tr('topic_$key'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),

          // Trending Section Header with Region & Topic Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    I18n.tr('home_trending_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      I18n.tr('topic_$currentTopic'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),

              // Country / Region Selector Popup on Home
              PopupMenuButton<String>(
                tooltip: 'Bölgeyi Değiştir',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                onSelected: (code) {
                  appState.setRegion(code);
                },
                itemBuilder: (ctx) {
                  return _regions.map((r) {
                    final isSel = r['code'] == currentRegion;
                    return PopupMenuItem<String>(
                      value: r['code'],
                      child: Row(
                        children: [
                          Text(r['flag'] ?? '', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r['name'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? AppColors.primaryBlue : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                          if (isSel)
                            const Icon(Icons.check_rounded, size: 16, color: AppColors.primaryBlue),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Text(currentRegionObj['flag'] ?? '🌐', style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        currentRegionObj['code'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Loading Indicator or Video Grid
          if (appState.isLoadingTrending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 80),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Trend videolar yükleniyor...'),
                ],
              ),
            )
          else if (appState.trendingVideos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 60),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.feed_outlined, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  const SizedBox(height: 12),
                  const Text('Bu kategori için video bulunamadı. Farklı bir kategori veya bölge seçin.'),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: 0.88,
              ),
              itemCount: appState.trendingVideos.length,
              itemBuilder: (context, index) {
                return VideoCard(video: appState.trendingVideos[index]);
              },
            ),
        ],
      ),
    );
  }
}
