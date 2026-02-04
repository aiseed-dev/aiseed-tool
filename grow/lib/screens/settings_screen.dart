import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

const kPlantIdApiKeyPref = 'plant_id_api_key';

class SettingsScreen extends StatefulWidget {
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _apiKey = prefs.getString(kPlantIdApiKeyPref) ?? '';
    });
  }

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
            subtitle: Text(_themeModeLabel(l, widget.themeMode)),
            onTap: () => _showThemeDialog(context, l),
          ),
          const Divider(height: 1),
          // Language
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            subtitle: Text(_localeLabel(widget.locale)),
            onTap: () => _showLanguageDialog(context, l),
          ),
          const Divider(height: 1),
          // Plant.id API Key
          ListTile(
            leading: const Icon(Icons.key),
            title: Text(l.plantIdApiKey),
            subtitle: Text(
              _apiKey.isEmpty
                  ? l.plantIdApiKeyHint
                  : '${'*' * (_apiKey.length > 8 ? 8 : _apiKey.length)}${_apiKey.substring(_apiKey.length > 4 ? _apiKey.length - 4 : 0)}',
            ),
            onTap: () => _showApiKeyDialog(context, l),
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
              widget.onThemeModeChanged(ThemeMode.system);
              Navigator.pop(ctx);
            },
            child: Text(l.systemMode),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.onThemeModeChanged(ThemeMode.light);
              Navigator.pop(ctx);
            },
            child: Text(l.lightMode),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.onThemeModeChanged(ThemeMode.dark);
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
              widget.onLocaleChanged(null);
              Navigator.pop(ctx);
            },
            child: const Text('System'),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.onLocaleChanged(const Locale('ja'));
              Navigator.pop(ctx);
            },
            child: const Text('日本語'),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.onLocaleChanged(const Locale('en'));
              Navigator.pop(ctx);
            },
            child: const Text('English'),
          ),
        ],
      ),
    );
  }

  Future<void> _showApiKeyDialog(
      BuildContext context, AppLocalizations l) async {
    final ctrl = TextEditingController(text: _apiKey);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.plantIdApiKey),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: l.plantIdApiKeyHint,
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPlantIdApiKeyPref, ctrl.text.trim());
    if (!mounted) return;
    setState(() => _apiKey = ctrl.text.trim());
  }
}
