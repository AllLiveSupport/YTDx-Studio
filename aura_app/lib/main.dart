import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'providers/player_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'widgets/player_bar.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: const AuraApp(),
    ),
  );
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeModeStr = context.select<AppState, String>((s) => s.settings.themeMode);

    ThemeMode mode;
    if (themeModeStr == 'light') {
      mode = ThemeMode.light;
    } else if (themeModeStr == 'dark') {
      mode = ThemeMode.dark;
    } else {
      mode = ThemeMode.system;
    }

    return MaterialApp(
      title: 'YTDx Downloader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycleListener;

  static const List<Widget> _screens = [
    HomeScreen(),
    SearchScreen(),
    DownloadsScreen(),
    PlaylistsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        PlayerProvider.cleanupAllAudioProcesses();
        return AppExitResponse.exit;
      },
      onDetach: () {
        PlayerProvider.cleanupAllAudioProcesses();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleListener.dispose();
    PlayerProvider.cleanupAllAudioProcesses();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      PlayerProvider.cleanupAllAudioProcesses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = context.select<AppState, int>((s) => s.currentTabIndex);

    return Scaffold(
      body: Column(
        children: [
          // Main Body: Sidebar + Active Screen
          Expanded(
            child: Row(
              children: [
                // Fixed Left Modern Sidebar
                const Sidebar(),

                // Active Page Content
                Expanded(
                  child: IndexedStack(
                    index: currentTabIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),

          // In-App Modern Media Player Bar
          const PlayerBar(),
        ],
      ),
    );
  }
}
