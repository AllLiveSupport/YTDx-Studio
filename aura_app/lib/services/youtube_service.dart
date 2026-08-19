import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_item.dart';
import 'backend_locator.dart';

class YouTubeService {
  static YoutubeExplode? _activeYt;
  static VideoSearchList? _activeSearchList;
  static final Map<String, _CachedSearch> _searchCache = {};

  /// Extracts 11-char YouTube video ID from any video, shorts, or share link
  static String? extractVideoId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // 1. Direct 11-character video ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
      return clean;
    }

    // 2. youtube.com/shorts/...
    final shortsMatch = RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})', caseSensitive: false).firstMatch(clean);
    if (shortsMatch != null) return shortsMatch.group(1);

    // 3. youtu.be/...
    final youtuMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})', caseSensitive: false).firstMatch(clean);
    if (youtuMatch != null) return youtuMatch.group(1);

    // 4. youtube.com/watch?v=...
    final vMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})', caseSensitive: false).firstMatch(clean);
    if (vMatch != null) return vMatch.group(1);

    // 5. youtube.com/embed/... or /v/... or /live/...
    final embedMatch = RegExp(r'youtube\.com/(?:embed|v|live)/([a-zA-Z0-9_-]{11})', caseSensitive: false).firstMatch(clean);
    if (embedMatch != null) return embedMatch.group(1);

    return null;
  }

  /// Fetches single video metadata directly by video ID (Pure Dart + yt-dlp fallback)
  static Future<VideoItem?> fetchDirectVideo(String videoId) async {
    // 1. Pure Dart Engine (YoutubeExplode)
    try {
      _activeYt?.close();
      _activeYt = YoutubeExplode();
      final v = await _activeYt!.videos.get(VideoId(videoId));
      String dur = '';
      if (v.duration != null) {
        final totalSec = v.duration!.inSeconds;
        final mins = totalSec ~/ 60;
        final secs = totalSec % 60;
        final hours = mins ~/ 60;
        final remMins = mins % 60;
        if (hours > 0) {
          dur = '${hours.toString().padLeft(2, '0')}:${remMins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        } else {
          dur = '${remMins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        }
      }

      return VideoItem(
        id: v.id.value,
        title: v.title,
        url: v.url,
        channel: v.author,
        duration: dur.isNotEmpty ? dur : '0:00',
        thumbnail: v.thumbnails.highResUrl.isNotEmpty
            ? v.thumbnails.highResUrl
            : 'https://i.ytimg.com/vi/${v.id.value}/maxresdefault.jpg',
        viewCount: v.engagement.viewCount.toString(),
        uploadDate: v.uploadDate?.toString(),
      );
    } catch (_) {}

    // 2. Subprocess Fallback (yt-dlp)
    try {
      final ytdlpExe = BackendLocator.findYtDlp();
      final process = await Process.run(
        ytdlpExe,
        [
          '--dump-json',
          '--no-warnings',
          '--no-check-certificate',
          '--no-playlist',
          'https://www.youtube.com/watch?v=$videoId',
        ],
      );

      if (process.exitCode == 0 && process.stdout.toString().isNotEmpty) {
        final json = jsonDecode(process.stdout.toString().trim());
        return VideoItem.fromJson(json);
      }
    } catch (_) {}

    return null;
  }

  /// Searches YouTube using Pure Dart engine (YoutubeExplode) with direct URL resolution, yt-dlp fallback and 0ms Memory Caching
  static Future<List<VideoItem>> searchVideos(String query, {bool forceRefresh = false}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Instant in-memory cache check (10-minute validity)
    if (!forceRefresh && _searchCache.containsKey(cleanQuery)) {
      final cached = _searchCache[cleanQuery]!;
      if (DateTime.now().difference(cached.timestamp).inMinutes < 10) {
        return cached.items;
      }
    }

    // 0. Direct YouTube Video or Shorts URL Detection
    final directVideoId = extractVideoId(cleanQuery);
    if (directVideoId != null) {
      final directItem = await fetchDirectVideo(directVideoId);
      if (directItem != null) {
        final directList = [directItem];
        _searchCache[cleanQuery] = _CachedSearch(items: directList, timestamp: DateTime.now());
        return directList;
      }
    }

    List<VideoItem> results = [];

    // 1. Pure Dart Engine (YoutubeExplode)
    try {
      _activeYt?.close();
      _activeYt = YoutubeExplode();
      _activeSearchList = await _activeYt!.search.search(cleanQuery);
      final items = _parseSearchList(_activeSearchList!);
      if (items.isNotEmpty) results = items;
    } catch (_) {}

    // 2. Subprocess Fallback (yt-dlp)
    if (results.isEmpty) {
      results = await _fallbackYtDlpSearch(cleanQuery);
    }

    if (results.isNotEmpty) {
      _searchCache[cleanQuery] = _CachedSearch(items: results, timestamp: DateTime.now());
    }

    return results;
  }

  /// Loads next batch of search results for infinite scrolling
  static Future<List<VideoItem>> loadMoreSearchResults() async {
    if (_activeSearchList == null) return [];
    try {
      final next = await _activeSearchList!.nextPage();
      if (next != null && next.isNotEmpty) {
        _activeSearchList = next;
        return _parseSearchList(next);
      }
    } catch (_) {}
    return [];
  }

  static List<VideoItem> _parseSearchList(Iterable<dynamic> videos) {
    final List<VideoItem> items = [];
    for (var v in videos) {
      String dur = '';
      if (v.duration != null) {
        final totalSec = v.duration!.inSeconds;
        final mins = totalSec ~/ 60;
        final secs = totalSec % 60;
        final hours = mins ~/ 60;
        final remMins = mins % 60;
        if (hours > 0) {
          dur = '${hours.toString().padLeft(2, '0')}:${remMins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        } else {
          dur = '${remMins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        }
      }

      items.add(VideoItem(
        id: v.id.value,
        title: v.title,
        url: v.url,
        channel: v.author,
        duration: dur.isNotEmpty ? dur : '0:00',
        thumbnail: v.thumbnails.highResUrl.isNotEmpty
            ? v.thumbnails.highResUrl
            : 'https://i.ytimg.com/vi/${v.id.value}/mqdefault.jpg',
        viewCount: null,
        uploadDate: v.uploadDate?.toString(),
      ));
    }
    return items;
  }

  static Future<List<VideoItem>> _fallbackYtDlpSearch(String query, {int limit = 30}) async {
    try {
      final ytdlpExe = BackendLocator.findYtDlp();
      final process = await Process.run(
        ytdlpExe,
        [
          '--flat-playlist',
          '--dump-json',
          '--no-warnings',
          '--no-check-certificate',
          '--extractor-args', 'youtube:player_client=android,web',
          'ytsearch$limit:$query',
        ],
      );

      if (process.exitCode == 0 && process.stdout.toString().isNotEmpty) {
        final lines = process.stdout.toString().trim().split('\n');
        final List<VideoItem> results = [];
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line.trim());
            results.add(VideoItem.fromJson(json));
          } catch (_) {}
        }
        return results;
      }
    } catch (_) {}
    return [];
  }

  /// Fetches Trending videos using authentic native language queries for each country & topic
  static Future<List<VideoItem>> fetchTrendingVideos({String region = 'TR', String topic = 'music'}) async {
    final query = _buildTrendingQuery(region, topic);
    return searchVideos(query);
  }

  static String _buildTrendingQuery(String region, String topic) {
    switch (region.toUpperCase()) {
      case 'KR':
        switch (topic) {
          case 'music': return '인기 급상승 음악 K-POP 2025 최신곡 뮤직비디오';
          case 'gaming': return '인기 급상승 게임 롤 배그 종합게임';
          case 'movies': return '영화 예고편 최신 한국 영화';
          case 'sports': return '스포츠 하이라이트 손흥민 축구 야구';
          case 'tech': return '테크 스마트폰 전자기기 IT 리뷰';
          case 'news': return '뉴스 속보 대한민국 주요 뉴스';
          case 'general':
          default: return '인기 급상승 동영상 한국 트렌드';
        }
      case 'JP':
        switch (topic) {
          case 'music': return '急上昇 音楽 J-POP 最新 ヒット曲 2025 MV';
          case 'gaming': return 'ゲーム実況 プレイ動画 人気 急上昇';
          case 'movies': return '映画 予告編 アニメ 劇場版 最新';
          case 'sports': return 'スポーツ ハイライト プロ野球 サッカー';
          case 'tech': return 'ガジェット レビュー テクノロジー 最新';
          case 'news': return 'ニュース 速報 報道 日本';
          case 'general':
          default: return '急上昇 日本 トレンド 人気動画';
        }
      case 'AZ':
        switch (topic) {
          case 'music': return 'Azərbaycan musiqisi yeni hit mahnılar 2025 klip';
          case 'gaming': return 'Oyun videoları Azərbaycan gameplay';
          case 'movies': return 'Azərbaycan film treylerləri kinolar';
          case 'sports': return 'İdman xülasələri futbol Azərbaycan';
          case 'tech': return 'Texnologiya xəbərləri icmallar telefon';
          case 'news': return 'Son xəbərlər Azərbaycan gündəm';
          case 'general':
          default: return 'Trend Azərbaycan populyar videolar';
        }
      case 'BR':
        switch (topic) {
          case 'music': return 'Top Músicas Brasil 2025 Hits Funk Sertanejo Trap';
          case 'gaming': return 'Gameplay Jogos Tendências Brasil';
          case 'movies': return 'Trailers de Filmes Lançamentos Cinema Brasil';
          case 'sports': return 'Futebol Melhores Momentos Brasileirão';
          case 'tech': return 'Tecnologia Análises Celulares Gadgets';
          case 'news': return 'Notícias Brasil Últimas Notícias Ao Vivo';
          case 'general':
          default: return 'Em Alta Brasil Vídeos Populares';
        }
      case 'IT':
        switch (topic) {
          case 'music': return 'Musica Tendenze Italia Canzoni 2025 Hit';
          case 'gaming': return 'Gameplay Videogiochi Tendenze Italia';
          case 'movies': return 'Trailer Film Uscite Cinema Italia';
          case 'sports': return 'Highlights Calcio Serie A Sport';
          case 'tech': return 'Tecnologia Recensioni Smartphone Gadget';
          case 'news': return 'Ultime Notizie Italia Oggi';
          case 'general':
          default: return 'Tendenze Italia Video Popolari';
        }
      case 'RU':
        switch (topic) {
          case 'music': return 'Популярная русская музыка хиты 2025 клипы';
          case 'gaming': return 'Игры летсплей гейминг топ прохождение';
          case 'movies': return 'Трейлеры фильмов новинки кино премьеры';
          case 'sports': return 'Спорт футбол хоккей матч обзор хайлайты';
          case 'tech': return 'Технологии обзоры гаджетов смартфоны';
          case 'news': return 'Новости Россия сегодня главное';
          case 'general':
          default: return 'Тренды популярное Россия';
        }
      case 'DE':
        switch (topic) {
          case 'music': return 'Deutsche Hits Charts Musik 2025 Offiziell';
          case 'gaming': return 'Gaming Gameplay Deutsch Trending';
          case 'movies': return 'Offizielle Film Trailer Deutsch Kino';
          case 'sports': return 'Sport Highlights Bundesliga Fußball Zusammenfassung';
          case 'tech': return 'Technik Testberichte Gadgets Smartphone';
          case 'news': return 'Nachrichten Deutschland Aktuell';
          case 'general':
          default: return 'Trends Deutschland Beliebte Videos';
        }
      case 'FR':
        switch (topic) {
          case 'music': return 'Top Hits Musique France 2025 Clip';
          case 'gaming': return 'Jeux Vidéo Gaming France Let s Play';
          case 'movies': return 'Bandes Annonces Films Cinéma France';
          case 'sports': return 'Sport Résumé Matchs Football Ligue 1';
          case 'tech': return 'Technologie Tests High-Tech';
          case 'news': return 'Actualités France Info Aujourd hui';
          case 'general':
          default: return 'Tendances France Vidéos Populaires';
        }
      case 'ES':
        switch (topic) {
          case 'music': return 'Éxitos Música España 2025 Top Canciones';
          case 'gaming': return 'Videojuegos Gaming Tendencias Gameplay';
          case 'movies': return 'Tráilers de Películas Cine Estrenos';
          case 'sports': return 'Deportes Resumen Fútbol LaLiga Resumen';
          case 'tech': return 'Tecnología Novedades Análisis Móviles';
          case 'news': return 'Noticias España Última Hora';
          case 'general':
          default: return 'Tendencias España Vídeos Populares';
        }
      case 'US':
      case 'GB':
      case 'GLOBAL':
        switch (topic) {
          case 'music': return 'Top Trending Music Hits 2025 Billboard Official';
          case 'gaming': return 'Trending Gaming Gameplay 2025 Walkthrough';
          case 'movies': return 'Official Movie Trailers 2025 Cinema';
          case 'sports': return 'Sports Highlights NBA NFL Premier League 2025';
          case 'tech': return 'Tech Reviews Gadgets Smartphones 2025';
          case 'news': return 'Breaking News Today Live Updates';
          case 'general':
          default: return 'Trending Videos Today Popular';
        }
      case 'TR':
      default:
        switch (topic) {
          case 'music': return 'Popüler Türkçe Müzikler 2025 Hit Şarkılar Klip';
          case 'gaming': return 'En Popüler Türkçe Oyun Videoları Gameplay';
          case 'movies': return 'Yeni Film Fragmanları Sinema Vizyon';
          case 'sports': return 'Spor Maç Özetleri Süper Lig Futbol';
          case 'tech': return 'Teknoloji İnceleme Yapay Zeka Telefon';
          case 'news': return 'Son Dakika Haberler Gündem Türkiye';
          case 'general':
          default: return 'Türkiye Trend Popüler Videolar';
        }
    }
  }

  /// Fetches all videos in a Playlist
  static Future<List<VideoItem>> fetchPlaylistVideos(String playlistUrl) async {
    final List<VideoItem> videos = [];

    // 1. Pure Dart
    try {
      final yt = YoutubeExplode();
      Playlist? playlist;
      try {
        playlist = await yt.playlists.get(playlistUrl);
      } catch (_) {
        final regExp = RegExp(r'[?&]list=([^#\&\?]+)');
        final match = regExp.firstMatch(playlistUrl);
        if (match != null) {
          playlist = await yt.playlists.get(match.group(1));
        }
      }

      if (playlist != null) {
        await for (final v in yt.playlists.getVideos(playlist.id)) {
          String dur = '';
          if (v.duration != null) {
            final totalSec = v.duration!.inSeconds;
            final mins = totalSec ~/ 60;
            final secs = totalSec % 60;
            dur = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
          }

          videos.add(VideoItem(
            id: v.id.value,
            title: v.title,
            url: v.url,
            channel: v.author,
            duration: dur.isNotEmpty ? dur : '0:00',
            thumbnail: v.thumbnails.highResUrl.isNotEmpty
                ? v.thumbnails.highResUrl
                : 'https://i.ytimg.com/vi/${v.id.value}/mqdefault.jpg',
            isSelected: true,
          ));
        }
        yt.close();
        if (videos.isNotEmpty) return videos;
      }
    } catch (_) {}

    // 2. yt-dlp Subprocess Fallback
    try {
      final ytdlpExe = BackendLocator.findYtDlp();
      final process = await Process.run(
        ytdlpExe,
        [
          '--flat-playlist',
          '--dump-json',
          '--no-warnings',
          '--no-check-certificate',
          '--extractor-args', 'youtube:player_client=android,web',
          playlistUrl,
        ],
      );

      if (process.exitCode == 0 && process.stdout.toString().isNotEmpty) {
        final lines = process.stdout.toString().trim().split('\n');
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line.trim());
            final item = VideoItem.fromJson(json);
            item.isSelected = true;
            videos.add(item);
          } catch (_) {}
        }
      }
    } catch (_) {}

    return videos;
  }
}

class _CachedSearch {
  final List<VideoItem> items;
  final DateTime timestamp;

  _CachedSearch({required this.items, required this.timestamp});
}
