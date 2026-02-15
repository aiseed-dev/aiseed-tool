import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'locations_screen.dart';
import 'crops_screen.dart';
import 'records_screen.dart';
import 'skill_screen.dart';
import '../services/database_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final screens = [
      RecordsScreen(db: widget.db),
      CropsScreen(db: widget.db),
      LocationsScreen(db: widget.db),
      SkillScreen(
        db: widget.db,
        onThemeModeChanged: widget.onThemeModeChanged,
        onLocaleChanged: widget.onLocaleChanged,
        themeMode: widget.themeMode,
        locale: widget.locale,
      ),
    ];

    return Scaffold(
      body: screens[_index],
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
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: l.skill,
          ),
        ],
      ),
    );
  }
}
