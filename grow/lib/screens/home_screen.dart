import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'locations_screen.dart';
import 'crops_screen.dart';
import 'records_screen.dart';
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
  final _chatConversationService = ChatConversationService();

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          onThemeModeChanged: widget.onThemeModeChanged,
          onLocaleChanged: widget.onLocaleChanged,
          themeMode: widget.themeMode,
          locale: widget.locale,
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: ChatScreen(conversationService: _chatConversationService),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final screens = [
      RecordsScreen(db: widget.db, onOpenSettings: _openSettings),
      CropsScreen(db: widget.db, onOpenSettings: _openSettings),
      LocationsScreen(db: widget.db, onOpenSettings: _openSettings),
    ];

    return Scaffold(
      body: screens[_index],
      floatingActionButton: FloatingActionButton(
        onPressed: _openChat,
        tooltip: 'AI Cowork',
        child: const Icon(Icons.auto_awesome),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.edit_note_outlined),
            selectedIcon: const Icon(Icons.edit_note),
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
        ],
      ),
    );
  }
}
