import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../services/native_folder_picker.dart';
import '../services/i18n.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showGoogleDeviceModal(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GoogleDeviceDialog(appState: appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasLinkedAccount = File('${Directory.current.path}/tokens.json').existsSync();

    final regions = [
      {'code': 'TR', 'name': '🇹🇷 Türkiye'},
      {'code': 'US', 'name': '🇺🇸 United States'},
      {'code': 'DE', 'name': '🇩🇪 Deutschland'},
      {'code': 'GB', 'name': '🇬🇧 United Kingdom'},
      {'code': 'ES', 'name': '🇪🇸 España'},
      {'code': 'RU', 'name': '🇷🇺 Россия'},
      {'code': 'FR', 'name': '🇫🇷 France'},
      {'code': 'GLOBAL', 'name': '🌍 Global Billboard'},
    ];

    final topics = [
      {'code': 'music', 'name': '🎵 ${I18n.tr('topic_music')}'},
      {'code': 'general', 'name': '🔥 ${I18n.tr('topic_general')}'},
      {'code': 'gaming', 'name': '🎮 ${I18n.tr('topic_gaming')}'},
      {'code': 'movies', 'name': '🎬 ${I18n.tr('topic_movies')}'},
      {'code': 'sports', 'name': '⚽ ${I18n.tr('topic_sports')}'},
      {'code': 'tech', 'name': '💻 ${I18n.tr('topic_tech')}'},
      {'code': 'news', 'name': '📰 ${I18n.tr('topic_news')}'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            I18n.tr('settings_title'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          // 1. Language Selection
          _SectionHeader(title: I18n.tr('settings_language_section'), isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                _LanguageTile(
                  flag: '🇹🇷',
                  name: 'Türkçe',
                  code: 'tr',
                  selectedCode: settings.language,
                  isDark: isDark,
                  onSelect: () => appState.setLanguage('tr'),
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _LanguageTile(
                  flag: '🇬🇧',
                  name: 'English',
                  code: 'en',
                  selectedCode: settings.language,
                  isDark: isDark,
                  onSelect: () => appState.setLanguage('en'),
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _LanguageTile(
                  flag: '🇪🇸',
                  name: 'Español',
                  code: 'es',
                  selectedCode: settings.language,
                  isDark: isDark,
                  onSelect: () => appState.setLanguage('es'),
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _LanguageTile(
                  flag: '🇷🇺',
                  name: 'Русский',
                  code: 'ru',
                  selectedCode: settings.language,
                  isDark: isDark,
                  onSelect: () => appState.setLanguage('ru'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Region & Topic Filter
          _SectionHeader(title: I18n.tr('settings_region_section'), isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Region Selector
                Text(
                  I18n.tr('settings_region_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF191B22) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.region,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      items: regions.map((r) {
                        return DropdownMenuItem<String>(
                          value: r['code'],
                          child: Text(r['name']!, style: const TextStyle(fontSize: 13.5)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          appState.setRegion(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Topic Selector
                Text(
                  I18n.tr('settings_topic_label'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF191B22) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.trendingTopic,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      items: topics.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['code'],
                          child: Text(t['name']!, style: const TextStyle(fontSize: 13.5)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          appState.setTrendingTopic(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Engine Selection
          _SectionHeader(title: I18n.tr('settings_engine_section'), isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            child: Column(
              children: [
                _EngineRadioTile(
                  icon: Icons.code_rounded,
                  iconColor: Colors.greenAccent,
                  title: I18n.tr('settings_engine_pytube_title'),
                  subtitle: I18n.tr('settings_engine_pytube_sub'),
                  value: 'pytubefix',
                  groupValue: settings.engine,
                  isDark: isDark,
                  onChanged: (val) {
                    settings.engine = 'pytubefix';
                    appState.saveSettings();
                  },
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _EngineRadioTile(
                  icon: Icons.speed_rounded,
                  iconColor: AppColors.primaryBlue,
                  title: I18n.tr('settings_engine_ytdlp_title'),
                  subtitle: I18n.tr('settings_engine_ytdlp_sub'),
                  value: 'ytdlp',
                  groupValue: settings.engine,
                  isDark: isDark,
                  onChanged: (val) {
                    settings.engine = 'ytdlp';
                    appState.saveSettings();
                  },
                ),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                _EngineRadioTile(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: Colors.cyanAccent,
                  title: I18n.tr('settings_engine_auto_title'),
                  subtitle: I18n.tr('settings_engine_auto_sub'),
                  value: 'auto',
                  groupValue: settings.engine,
                  isDark: isDark,
                  onChanged: (val) {
                    settings.engine = 'auto';
                    appState.saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Google Device Flow & Bot Protection
          _SectionHeader(title: I18n.tr('settings_google_section'), isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasLinkedAccount
                            ? Colors.greenAccent.withValues(alpha: 0.15)
                            : Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasLinkedAccount ? Icons.verified_user_rounded : Icons.security_rounded,
                        color: hasLinkedAccount ? Colors.greenAccent : Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                I18n.tr('settings_google_title'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (hasLinkedAccount)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Doğrulandı ✅',
                                    style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            I18n.tr('settings_google_sub'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    // Generate Device Code Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.vpn_key_rounded, size: 16),
                      label: Text(I18n.tr('settings_google_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showGoogleDeviceModal(context, appState),
                    ),

                    const SizedBox(width: 12),

                    // Clear Tokens Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(I18n.tr('settings_google_reset'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        try {
                          final f = File('${Directory.current.path}/tokens.json');
                          if (f.existsSync()) f.deleteSync();
                        } catch (_) {}
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kayıtlı OAuth ve PoToken önbelleği temizlendi.')),
                        );
                        appState.saveSettings();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                const SizedBox(height: 12),

                // Automatic Browser Cookies Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            I18n.tr('settings_cookies_title'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            I18n.tr('settings_cookies_sub'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.browserCookies != 'none',
                      activeThumbColor: AppColors.primaryBlue,
                      activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
                      onChanged: (enabled) {
                        settings.browserCookies = enabled ? 'auto' : 'none';
                        appState.saveSettings();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Download Location
          _SectionHeader(title: I18n.tr('settings_download_path'), isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PathRow(
                  label: I18n.tr('downloads_folder'),
                  path: settings.downloadPath,
                  isDark: isDark,
                  onBrowse: () async {
                    final selected = await NativeFolderPicker.pickDirectory();
                    if (selected != null && selected.isNotEmpty) {
                      settings.downloadPath = selected;
                      appState.saveSettings();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 6. Developer & GitHub Section
          _SectionHeader(title: I18n.tr('settings_about'), isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2129) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: const Icon(Icons.code_rounded, color: AppColors.primaryBlue, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YTDx Downloader Pro',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Developer: AllLiveSupport (GitHub)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(I18n.tr('settings_open_github'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse('https://github.com/AllLiveSupport');
                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleDeviceDialog extends StatefulWidget {
  final AppState appState;
  const _GoogleDeviceDialog({required this.appState});

  @override
  State<_GoogleDeviceDialog> createState() => _GoogleDeviceDialogState();
}

class _GoogleDeviceDialogState extends State<_GoogleDeviceDialog> {
  bool _isLoading = true;
  String? _userCode;
  String? _verificationUrl;
  String? _errorMessage;
  bool _isAuthorized = false;
  StreamSubscription<bool>? _pollSubscription;

  @override
  void initState() {
    super.initState();
    _fetchRealGoogleCode();
  }

  Future<void> _fetchRealGoogleCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService.initiateDeviceAuth();
    if (res['status'] == 'ok') {
      final uCode = res['user_code'] as String;
      final dCode = res['device_code'] as String;
      final vUrl = res['verification_url'] as String;
      final interval = res['interval'] as int? ?? 5;

      setState(() {
        _userCode = uCode;
        _verificationUrl = vUrl;
        _isLoading = false;
      });

      // Auto copy real Google user code to clipboard
      await Clipboard.setData(ClipboardData(text: uCode));

      // Start real token polling in pure Dart
      _pollSubscription = AuthService.pollDeviceToken(dCode, intervalSeconds: interval).listen((isAuth) {
        if (isAuth && mounted) {
          setState(() {
            _isAuthorized = true;
          });
          widget.appState.saveSettings();
        }
      });
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Google API hatası oluştu.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pollSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.devices_rounded, color: Colors.redAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'Google Device Doğrulama',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryBlue),
                  SizedBox(height: 16),
                  Text('Google sunucularından resmi cihaz kodu alınıyor...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchRealGoogleCode,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                )
              : _isAuthorized
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
                          SizedBox(height: 14),
                          Text(
                            'Google Hesabınız Başarıyla Doğrulandı!',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                          ),
                          SizedBox(height: 6),
                          Text('Artık bot ve IP engelleri olmadan hızlı indirme yapabilirsiniz.'),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aşağıdaki resmi Google kodunu açılan sayfadaki kutucuğa girip onaylayın:',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Code Container with Copy Button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF13151A) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SelectableText(
                                _userCode ?? '',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: AppColors.primaryBlue, size: 20),
                                tooltip: 'Kodu Kopyala',
                                onPressed: () {
                                  if (_userCode != null) {
                                    Clipboard.setData(ClipboardData(text: _userCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Kod panoya kopyalandı!')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                            SizedBox(width: 6),
                            Text(
                              'Kod otomatik olarak panonuza kopyalandı!',
                              style: TextStyle(fontSize: 11.5, color: Colors.greenAccent, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Google sayfasında doğrulama bekleniyor...',
                              style: TextStyle(fontSize: 11.5, color: Colors.cyanAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_isAuthorized ? 'Kapat' : I18n.tr('modal_btn_cancel')),
        ),
        if (!_isLoading && _errorMessage == null && !_isAuthorized)
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('google.com/device Aç', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final uri = Uri.parse(_verificationUrl ?? 'https://www.google.com/device');
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
            },
          ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String flag;
  final String name;
  final String code;
  final String selectedCode;
  final bool isDark;
  final VoidCallback onSelect;

  const _LanguageTile({
    required this.flag,
    required this.name,
    required this.code,
    required this.selectedCode,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = code == selectedCode;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _SettingsCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: child,
    );
  }
}

class _PathRow extends StatelessWidget {
  final String label;
  final String path;
  final bool isDark;
  final Function() onBrowse;

  const _PathRow({
    required this.label,
    required this.path,
    required this.isDark,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF191B22) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Text(
                  path.isEmpty ? 'Seçilmedi' : path,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: path.isEmpty
                        ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: Text(I18n.tr('settings_browse'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF232732) : const Color(0xFFE2E8F0),
                foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: onBrowse,
            ),
          ],
        ),
      ],
    );
  }
}

class _EngineRadioTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final bool isDark;
  final Function(String?) onChanged;

  const _EngineRadioTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primaryBlue
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 5.5 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
