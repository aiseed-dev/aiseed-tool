import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import 'locations_screen.dart';
import 'crops_screen.dart';
import 'records_screen.dart';
import 'skill_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import '../services/database_service.dart';
import '../services/chat_conversation_service.dart';

class HomeScreen extends StatefulWidget {
  final DatabaseService db;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final ThemeMode themeMode;
  final Locale? locale;

  const HomeScreen({
    super.key,
    required this.db,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.locale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _serverConnected = false;
  final _chatService = ChatConversationService();

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(kServerUrlPref) ?? '';
    final token = prefs.getString(kServerTokenPref) ?? '';
    if (!mounted) return;
    final connected = url.isNotEmpty && token.isNotEmpty;
    if (connected != _serverConnected) {
      setState(() {
        _serverConnected = connected;
        // インデックスが範囲外にならないようにする
        if (_index >= _screenCount) _index = 0;
      });
    }
  }

  int get _screenCount => _serverConnected ? 5 : 4;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final screens = <Widget>[
      RecordsScreen(db: widget.db),
      CropsScreen(db: widget.db),
      LocationsScreen(db: widget.db),
      if (_serverConnected)
        ChatScreen(
          conversationService: _chatService,
          onOpenSettings: () {
            // スキルズ画面の設定ボタンと同じ
          },
        ),
      SkillScreen(
        db: widget.db,
        onThemeModeChanged: widget.onThemeModeChanged,
        onLocaleChanged: widget.onLocaleChanged,
        themeMode: widget.themeMode,
        locale: widget.locale,
        onServerChanged: _checkServer,
      ),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.visibility_outlined),
        selectedIcon: const Icon(Icons.visibility),
        label: l.records,
      ),
      NavigationDestination(
        icon: const Icon(Icons.eco_outlined),
        selectedIcon: const Icon(Icons.eco),
        label: l.crops,
      ),
      NavigationDestination(
        icon: const Icon(Icons.place_outlined),
        selectedIcon: const Icon(Icons.place),
        label: l.locations,
      ),
      if (_serverConnected)
        const NavigationDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'AI',
        ),
      NavigationDestination(
        icon: const Icon(Icons.auto_awesome_outlined),
        selectedIcon: const Icon(Icons.auto_awesome),
        label: l.skill,
      ),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
