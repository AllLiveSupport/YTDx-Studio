import 'dart:io';

class AppSettings {
  String themeMode; // 'dark', 'light', 'system'
  String language; // 'tr', 'en', 'es', 'ru'
  String region; // 'TR', 'US', 'DE', 'GB', 'ES', 'RU', 'FR', 'GLOBAL'
  String trendingTopic; // 'music', 'general', 'gaming', 'movies', 'sports', 'tech', 'news'
  String engine; // 'auto', 'ytdlp', 'pytubefix'
  String downloadPreset; // 'auto_highest', 'ask_always'
  String defaultAudioFormat; // 'mp3', 'm4a', 'flac'
  String defaultVideoQuality; // 'auto', '1080p', '4k'
  String browserCookies; // 'none', 'firefox', 'chrome', 'brave', 'edge'
  String downloadPath;
  String ffmpegPath;
  bool isGoogleLinked;

  AppSettings({
    this.themeMode = 'dark',
    this.language = 'tr',
    this.region = 'TR',
    this.trendingTopic = 'music',
    this.engine = 'pytubefix',
    this.downloadPreset = 'ask_always',
    this.defaultAudioFormat = 'mp3',
    this.defaultVideoQuality = 'auto',
    this.browserCookies = 'none',
    this.downloadPath = '',
    this.ffmpegPath = 'ffmpeg',
    this.isGoogleLinked = false,
  });

  factory AppSettings.defaultSettings() {
    String defaultPath = '';
    if (Platform.isLinux || Platform.isMacOS) {
      String home = Platform.environment['HOME'] ?? '';
      defaultPath = '$home/Desktop';
    } else if (Platform.isWindows) {
      String userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\';
      defaultPath = '$userProfile\\Downloads';
    }
    return AppSettings(downloadPath: defaultPath);
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    var def = AppSettings.defaultSettings();
    return AppSettings(
      themeMode: json['themeMode'] ?? def.themeMode,
      language: json['language'] ?? def.language,
      region: json['region'] ?? def.region,
      trendingTopic: json['trendingTopic'] ?? def.trendingTopic,
      engine: json['engine'] ?? def.engine,
      downloadPreset: json['downloadPreset'] ?? def.downloadPreset,
      defaultAudioFormat: json['defaultAudioFormat'] ?? def.defaultAudioFormat,
      defaultVideoQuality: json['defaultVideoQuality'] ?? def.defaultVideoQuality,
      browserCookies: json['browserCookies'] ?? def.browserCookies,
      downloadPath: json['downloadPath'] ?? def.downloadPath,
      ffmpegPath: json['ffmpegPath'] ?? def.ffmpegPath,
      isGoogleLinked: json['isGoogleLinked'] ?? def.isGoogleLinked,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode,
    'language': language,
    'region': region,
    'trendingTopic': trendingTopic,
    'engine': engine,
    'downloadPreset': downloadPreset,
    'defaultAudioFormat': defaultAudioFormat,
    'defaultVideoQuality': defaultVideoQuality,
    'browserCookies': browserCookies,
    'downloadPath': downloadPath,
    'ffmpegPath': ffmpegPath,
    'isGoogleLinked': isGoogleLinked,
  };
}
