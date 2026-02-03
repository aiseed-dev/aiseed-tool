import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final ThemeMode themeMode;
  final Locale? locale;

  const SettingsScreen({
    super.key,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          // Theme
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l.theme),
            subtitle: Text(_themeModeLabel(l, themeMode)),
            onTap: () => _showThemeDialog(context, l),
          ),
          const Divider(height: 1),
          // Language
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            subtitle: Text(_localeLabel(locale)),
            onTap: () => _showLanguageDialog(context, l),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  String _themeModeLabel(AppLocalizations l, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return l.lightMode;
      case ThemeMode.dark:
        return l.darkMode;
      case ThemeMode.system:
        return l.systemMode;
    }
  }

  String _localeLabel(Locale? locale) {
    if (locale == null) return 'System';
    switch (locale.languageCode) {
      case 'ja':
        return '日本語';
      case 'en':
        return 'English';
      default:
        return locale.languageCode;
    }
  }

  void _showThemeDialog(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.theme),
        children: [
          SimpleDialogOption(
            onPressed: () {
              onThemeModeChanged(ThemeMode.system);
              Navigator.pop(ctx);
            },
            child: Text(l.systemMode),
          ),
          SimpleDialogOption(
            onPressed: () {
              onThemeModeChanged(ThemeMode.light);
              Navigator.pop(ctx);
            },
            child: Text(l.lightMode),
          ),
          SimpleDialogOption(
            onPressed: () {
              onThemeModeChanged(ThemeMode.dark);
              Navigator.pop(ctx);
            },
            child: Text(l.darkMode),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.language),
        children: [
          SimpleDialogOption(
            onPressed: () {
              onLocaleChanged(null);
              Navigator.pop(ctx);
            },
            child: const Text('System'),
          ),
          SimpleDialogOption(
            onPressed: () {
              onLocaleChanged(const Locale('ja'));
              Navigator.pop(ctx);
            },
            child: const Text('日本語'),
          ),
          SimpleDialogOption(
            onPressed: () {
              onLocaleChanged(const Locale('en'));
              Navigator.pop(ctx);
            },
            child: const Text('English'),
          ),
        ],
      ),
    );
  }
}
