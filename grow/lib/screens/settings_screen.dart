import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../services/plant_identification_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';

const kPlantIdProviderPref = 'plant_id_provider';
const kPlantIdApiKeyPref = 'plant_id_api_key';
const kServerUrlPref = 'server_url';
const kServerTokenPref = 'server_token';

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
  PlantIdProvider _provider = PlantIdProvider.off;
  SyncMode _syncMode = SyncMode.local;
  String _plantIdApiKey = '';
  String _serverUrl = '';
  String _serverToken = '';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final providerIndex = prefs.getInt(kPlantIdProviderPref) ?? 0;
      _provider = PlantIdProvider.values[
          providerIndex.clamp(0, PlantIdProvider.values.length - 1)];
      final syncIndex = prefs.getInt(kSyncModePref) ?? 0;
      _syncMode = SyncMode.values[
          syncIndex.clamp(0, SyncMode.values.length - 1)];
      _plantIdApiKey = prefs.getString(kPlantIdApiKeyPref) ?? '';
      _serverUrl = prefs.getString(kServerUrlPref) ?? '';
      _serverToken = prefs.getString(kServerTokenPref) ?? '';
    });
  }

  String _maskedKey(String key) {
    if (key.isEmpty) return '';
    final stars = '*' * (key.length > 8 ? 8 : key.length);
    final tail = key.length > 4 ? key.substring(key.length - 4) : key;
    return '$stars$tail';
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
          // Plant identification provider
          ListTile(
            leading: const Icon(Icons.eco),
            title: Text(l.plantIdProvider),
            subtitle: Text(_providerLabel(l, _provider)),
            onTap: () => _showProviderDialog(context, l),
          ),
          const Divider(height: 1),
          // Provider-specific settings
          if (_provider == PlantIdProvider.plantId) ...[
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(l.plantIdApiKey),
              subtitle: Text(
                _plantIdApiKey.isEmpty
                    ? l.plantIdApiKeyHint
                    : _maskedKey(_plantIdApiKey),
              ),
              onTap: () => _showTextDialog(
                context, l,
                title: l.plantIdApiKey,
                hint: l.plantIdApiKeyHint,
                currentValue: _plantIdApiKey,
                obscure: true,
                onSave: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(kPlantIdApiKeyPref, v);
                  if (!mounted) return;
                  setState(() => _plantIdApiKey = v);
                },
              ),
            ),
            const Divider(height: 1),
          ],
          // Server URL & token (shown when server provider or cloudflare sync)
          if (_provider == PlantIdProvider.server ||
              _syncMode == SyncMode.cloudflare) ...[
            ListTile(
              leading: const Icon(Icons.dns),
              title: Text(l.serverUrl),
              subtitle: Text(
                _serverUrl.isEmpty ? l.serverUrlHint : _serverUrl,
              ),
              onTap: () => _showTextDialog(
                context, l,
                title: l.serverUrl,
                hint: l.serverUrlHint,
                currentValue: _serverUrl,
                obscure: false,
                onSave: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(kServerUrlPref, v);
                  if (!mounted) return;
                  setState(() => _serverUrl = v);
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(l.serverToken),
              subtitle: Text(
                _serverToken.isEmpty
                    ? l.serverTokenHint
                    : _maskedKey(_serverToken),
              ),
              onTap: () => _showTextDialog(
                context, l,
                title: l.serverToken,
                hint: l.serverTokenHint,
                currentValue: _serverToken,
                obscure: true,
                onSave: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(kServerTokenPref, v);
                  if (!mounted) return;
                  setState(() => _serverToken = v);
                },
              ),
            ),
            const Divider(height: 1),
          ],
          // Data sync
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(l.dataSync),
            subtitle: Text(_syncModeLabel(l, _syncMode)),
            onTap: () => _showSyncModeDialog(context, l),
          ),
          const Divider(height: 1),
          if (_syncMode == SyncMode.cloudflare) ...[
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(l.syncNow),
              subtitle: _syncing ? Text(l.syncing) : null,
              trailing: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              onTap: _syncing ? null : () => _runSync(context, l),
            ),
            const Divider(height: 1),
          ],
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

  String _providerLabel(AppLocalizations l, PlantIdProvider provider) {
    switch (provider) {
      case PlantIdProvider.off:
        return l.plantIdProviderOff;
      case PlantIdProvider.plantId:
        return l.plantIdProviderPlantId;
      case PlantIdProvider.server:
        return l.plantIdProviderServer;
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

  void _showProviderDialog(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.plantIdProvider),
        children: [
          _providerOption(
            ctx, l,
            provider: PlantIdProvider.off,
            title: l.plantIdProviderOff,
            subtitle: l.plantIdProviderOffDesc,
          ),
          _providerOption(
            ctx, l,
            provider: PlantIdProvider.plantId,
            title: l.plantIdProviderPlantId,
            subtitle: l.plantIdProviderPlantIdDesc,
          ),
          _providerOption(
            ctx, l,
            provider: PlantIdProvider.server,
            title: l.plantIdProviderServer,
            subtitle: l.plantIdProviderServerDesc,
          ),
        ],
      ),
    );
  }

  Widget _providerOption(
    BuildContext ctx,
    AppLocalizations l, {
    required PlantIdProvider provider,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _provider == provider;
    return SimpleDialogOption(
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kPlantIdProviderPref, provider.index);
        if (!mounted) return;
        setState(() => _provider = provider);
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
            color: isSelected
                ? Theme.of(ctx).colorScheme.primary
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  subtitle,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _syncModeLabel(AppLocalizations l, SyncMode mode) {
    switch (mode) {
      case SyncMode.local:
        return l.syncModeLocal;
      case SyncMode.cloudflare:
        return l.syncModeCloudflare;
    }
  }

  void _showSyncModeDialog(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.dataSync),
        children: [
          _syncModeOption(ctx, l,
              mode: SyncMode.local,
              title: l.syncModeLocal,
              subtitle: l.syncModeLocalDesc),
          _syncModeOption(ctx, l,
              mode: SyncMode.cloudflare,
              title: l.syncModeCloudflare,
              subtitle: l.syncModeCloudflareDesc),
        ],
      ),
    );
  }

  Widget _syncModeOption(
    BuildContext ctx,
    AppLocalizations l, {
    required SyncMode mode,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _syncMode == mode;
    return SimpleDialogOption(
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kSyncModePref, mode.index);
        if (!mounted) return;
        setState(() => _syncMode = mode);
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
            color: isSelected
                ? Theme.of(ctx).colorScheme.primary
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(subtitle, style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runSync(BuildContext context, AppLocalizations l) async {
    if (_serverUrl.isEmpty || _serverToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.serverUrlHint)),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final syncService = SyncService(
        db: DatabaseService(),
        serverUrl: _serverUrl,
        serverToken: _serverToken,
      );
      final result = await syncService.sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.syncComplete(
            result.pulled, result.pushed, result.photosUploaded)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.syncFailed)),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _showTextDialog(
    BuildContext context,
    AppLocalizations l, {
    required String title,
    required String hint,
    required String currentValue,
    required bool obscure,
    required Future<void> Function(String) onSave,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          obscureText: obscure,
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
    await onSave(ctrl.text.trim());
  }
}
