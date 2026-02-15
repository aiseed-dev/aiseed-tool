import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/skill_file_generator.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'site_screen.dart';
import 'seed_packets_screen.dart';
import 'materials_screen.dart';
import 'shipping_slips_screen.dart';
import 'sales_slips_screen.dart';

// Structured skill profile SharedPreferences keys
const kSkillCropsPref = 'skill_crops';
const kSkillLocationPref = 'skill_location';
const kSkillMethodPref = 'skill_method';
const kSkillExperiencePref = 'skill_experience';
const kSkillChallengesPref = 'skill_challenges';

class SkillScreen extends StatefulWidget {
  final DatabaseService db;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final ThemeMode themeMode;
  final Locale? locale;
  final VoidCallback? onServerChanged;

  const SkillScreen({
    super.key,
    required this.db,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.locale,
    this.onServerChanged,
  });

  @override
  State<SkillScreen> createState() => _SkillScreenState();
}

class _SkillScreenState extends State<SkillScreen> {
  List<String> _crops = [];
  String _location = '';
  String _method = '';
  String _experience = '';
  String _challenges = '';

  String _serverUrl = '';
  String _serverToken = '';

  bool _loaded = false;
  bool _skillsExpanded = false;
  bool _serverExpanded = false;
  bool _formsExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final cropsStr = prefs.getString(kSkillCropsPref) ?? '';
      _crops = cropsStr.isEmpty ? [] : cropsStr.split(',');
      _location = prefs.getString(kSkillLocationPref) ?? '';
      _method = prefs.getString(kSkillMethodPref) ?? '';
      _experience = prefs.getString(kSkillExperiencePref) ?? '';
      _challenges = prefs.getString(kSkillChallengesPref) ?? '';

      _serverUrl = prefs.getString(kServerUrlPref) ?? '';
      _serverToken = prefs.getString(kServerTokenPref) ?? '';
      _loaded = true;
    });
  }

  bool get _hasProfile => _method.isNotEmpty && _experience.isNotEmpty;

  GrowProfile get _profile => GrowProfile(
        crops: _crops,
        location: _location,
        farmingMethod: _method,
        experience: _experience,
        challenges: _challenges,
      );

  void _openSystemSettings() {
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

  Future<void> _openOnboarding() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('スキルズ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'システム設定',
            onPressed: _openSystemSettings,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _hasProfile
              ? _buildProfile()
              : _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '栽培プロフィールを設定しましょう',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '5つの質問に答えて、あなた専用の\n栽培AIアシスタントをつくります',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openOnboarding,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('はじめる'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isServerConnected =>
      _serverUrl.isNotEmpty && _serverToken.isNotEmpty;

  Widget _buildProfile() {
    final methodLabel =
        SkillFileGenerator.farmingMethods[_method] ?? _method;
    final expLabel =
        SkillFileGenerator.experienceLevels[_experience] ?? _experience;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // スキルズ セクション
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('スキルズ'),
            subtitle: Text(
              '$methodLabel・$expLabel',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            initiallyExpanded: _skillsExpanded,
            onExpansionChanged: (v) => setState(() => _skillsExpanded = v),
            children: [
              const Divider(height: 1),
              _profileTile(
                icon: Icons.agriculture,
                title: '農法',
                value: methodLabel,
                onTap: _editMethod,
              ),
              const Divider(height: 1, indent: 56),
              _profileTile(
                icon: Icons.school,
                title: '経験',
                value: expLabel,
                onTap: _editExperience,
              ),
              const Divider(height: 1, indent: 56),
              _profileTile(
                icon: Icons.place,
                title: '栽培場所',
                value: _location.isEmpty ? '未設定' : _location,
                onTap: _editLocation,
              ),
              const Divider(height: 1, indent: 56),
              _profileTile(
                icon: Icons.eco,
                title: '栽培作物',
                value: _crops.isEmpty ? '未設定' : _crops.join('、'),
                onTap: _editCrops,
              ),
              const Divider(height: 1, indent: 56),
              _profileTile(
                icon: Icons.help_outline,
                title: '課題',
                value: _challenges.isEmpty ? '未設定' : _challenges,
                onTap: _editChallenges,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copySkillFile,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('ファイルをコピー'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openOnboarding,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('再設定'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // サーバー接続 セクション
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: Icon(
              _isServerConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isServerConnected
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: const Text('サーバー接続'),
            subtitle: Text(
              _isServerConnected ? '接続済み' : '未接続（オフラインモード）',
              style: TextStyle(
                fontSize: 13,
                color: _isServerConnected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            initiallyExpanded: _serverExpanded,
            onExpansionChanged: (v) => setState(() => _serverExpanded = v),
            children: [
              const Divider(height: 1),
              _profileTile(
                icon: Icons.dns,
                title: 'サーバーURL',
                value: _serverUrl.isEmpty ? '未設定' : _serverUrl,
                onTap: _editServerUrl,
              ),
              const Divider(height: 1, indent: 56),
              _profileTile(
                icon: Icons.key,
                title: 'トークン',
                value: _serverToken.isEmpty
                    ? '未設定'
                    : _maskedKey(_serverToken),
                onTap: _editServerToken,
              ),
              if (_isServerConnected) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'AIチャット・植物同定・データ同期が利用できます',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 伝票入力 セクション（スマホはカメラ入力のみ）
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('伝票入力'),
            subtitle: Text(
              '種袋・資材・出荷・売上',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            initiallyExpanded: _formsExpanded,
            onExpansionChanged: (v) => setState(() => _formsExpanded = v),
            children: [
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.grass),
                title: const Text('種袋'),
                subtitle: const Text('種袋の管理・記録'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeedPacketsScreen(db: widget.db),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('資材'),
                subtitle: const Text('資材・道具の管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaterialsScreen(db: widget.db),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('出荷伝票'),
                subtitle: const Text('出荷の記録・管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShippingSlipsScreen(db: widget.db),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('売上伝票'),
                subtitle: const Text('売上の記録・管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalesSlipsScreen(db: widget.db),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Web作成 セクション
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.web),
            title: const Text('Web作成'),
            subtitle: Text(
              'ホームページ作成・公開',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSiteScreen,
          ),
        ),
      ],
    );
  }

  void _openSiteScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteScreen(db: widget.db),
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _maskedKey(String key) {
    if (key.isEmpty) return '';
    final stars = '*' * (key.length > 8 ? 8 : key.length);
    final tail = key.length > 4 ? key.substring(key.length - 4) : key;
    return '$stars$tail';
  }

  // -- Edit dialogs --

  Future<void> _editMethod() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('農法'),
        children: SkillFileGenerator.farmingMethods.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.key),
            child: Row(
              children: [
                Icon(
                  _method == e.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: _method == e.key
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(e.value)),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSkillMethodPref, result);
    setState(() => _method = result);
  }

  Future<void> _editExperience() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('経験'),
        children: SkillFileGenerator.experienceLevels.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.key),
            child: Row(
              children: [
                Icon(
                  _experience == e.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: _experience == e.key
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(e.value)),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSkillExperiencePref, result);
    setState(() => _experience = result);
  }

  Future<void> _editLocation() async {
    final ctrl = TextEditingController(text: _location);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('栽培場所'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '例: 神奈川県・庭の菜園',
          ),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSkillLocationPref, result);
    setState(() => _location = result);
  }

  Future<void> _editCrops() async {
    final ctrl = TextEditingController(text: _crops.join('、'));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('栽培作物'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'トマト、ナス、キュウリ',
            helperText: 'カンマまたは読点で区切ってください',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final crops = result
        .split(RegExp(r'[,、\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSkillCropsPref, crops.join(','));
    setState(() => _crops = crops);
  }

  Future<void> _editChallenges() async {
    final ctrl = TextEditingController(text: _challenges);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('現在の課題'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '例: 害虫対策、土づくり',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSkillChallengesPref, result);
    setState(() => _challenges = result);
  }

  Future<void> _editServerUrl() async {
    final ctrl = TextEditingController(text: _serverUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('サーバーURL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://your-server.example.com',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kServerUrlPref, result);
    setState(() => _serverUrl = result);
    widget.onServerChanged?.call();
  }

  Future<void> _editServerToken() async {
    final ctrl = TextEditingController(text: _serverToken);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('トークン'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '管理者から受け取ったトークン',
          ),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kServerTokenPref, result);
    setState(() => _serverToken = result);
    widget.onServerChanged?.call();
  }

  void _copySkillFile() {
    final skillFile = SkillFileGenerator.generate(_profile);
    Clipboard.setData(ClipboardData(text: skillFile));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('スキルズファイルをコピーしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
