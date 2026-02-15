import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/skill_file_generator.dart';
import '../services/ai_chat_service.dart';
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

  const SkillScreen({
    super.key,
    required this.db,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.locale,
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

  AiProvider _aiProvider = AiProvider.gemini;
  String _aiApiKey = '';
  String _aiModel = '';

  bool _loaded = false;
  bool _skillsExpanded = false;
  bool _aiExpanded = false;
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

      final aiIdx = prefs.getInt(kAiProviderPref) ?? 0;
      _aiProvider =
          AiProvider.values[aiIdx.clamp(0, AiProvider.values.length - 1)];
      _aiApiKey = prefs.getString(kAiApiKeyPref) ?? '';
      _aiModel = prefs.getString(kAiModelPref) ?? '';
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

  Widget _buildProfile() {
    final methodLabel =
        SkillFileGenerator.farmingMethods[_method] ?? _method;
    final expLabel =
        SkillFileGenerator.experienceLevels[_experience] ?? _experience;
    final aiLabel = _aiProvider == AiProvider.gemini
        ? 'Gemini'
        : _aiProvider == AiProvider.claude
            ? 'Claude'
            : 'FastAPI';

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

        // AI設定 セクション
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('AI設定'),
            subtitle: Text(
              '$aiLabel・${_aiModelLabel()}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            initiallyExpanded: _aiExpanded,
            onExpansionChanged: (v) => setState(() => _aiExpanded = v),
            children: [
              const Divider(height: 1),
              _profileTile(
                icon: Icons.smart_toy,
                title: 'AIプロバイダー',
                value: _aiProvider == AiProvider.gemini
                    ? 'Gemini（無料枠あり）'
                    : 'Claude（従量課金）',
                onTap: _editAiProvider,
              ),
              const Divider(height: 1, indent: 56),
              _profileTile(
                icon: Icons.key,
                title: 'APIキー',
                value: _aiApiKey.isEmpty ? '未設定' : _maskedKey(_aiApiKey),
                onTap: _editAiApiKey,
              ),
              const Divider(height: 1, indent: 56),
              _profileTile(
                icon: Icons.memory,
                title: 'AIモデル',
                value: _aiModelLabel(),
                onTap: _editAiModel,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 帳票管理 セクション
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('帳票管理'),
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

  String _aiModelLabel() {
    if (_aiModel.isEmpty) return 'デフォルト';
    final models = AiChatService.modelsFor(_aiProvider);
    for (final m in models) {
      if (m.$1 == _aiModel) return m.$2;
    }
    return _aiModel;
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

  Future<void> _editAiProvider() async {
    final result = await showDialog<AiProvider>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('AIプロバイダー'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AiProvider.gemini),
            child: Row(
              children: [
                Icon(
                  _aiProvider == AiProvider.gemini
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: _aiProvider == AiProvider.gemini
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gemini'),
                      Text('Google AI - 無料枠あり',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, AiProvider.claude),
            child: Row(
              children: [
                Icon(
                  _aiProvider == AiProvider.claude
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: _aiProvider == AiProvider.claude
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Claude'),
                      Text('Anthropic - 従量課金',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kAiProviderPref, result.index);
    await prefs.setString(kAiModelPref, '');
    setState(() {
      _aiProvider = result;
      _aiModel = '';
    });
  }

  Future<void> _editAiApiKey() async {
    final ctrl = TextEditingController(text: _aiApiKey);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI APIキー'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: _aiProvider == AiProvider.gemini
                ? 'AIza...'
                : 'sk-ant-...',
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
    await prefs.setString(kAiApiKeyPref, result);
    setState(() => _aiApiKey = result);
  }

  Future<void> _editAiModel() async {
    final models = AiChatService.modelsFor(_aiProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('AIモデル'),
        children: models.map((m) {
          final isSelected =
              _aiModel == m.$1 || (_aiModel.isEmpty && m == models.first);
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, m.$1),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: isSelected
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                Text(m.$2),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAiModelPref, result);
    setState(() => _aiModel = result);
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
