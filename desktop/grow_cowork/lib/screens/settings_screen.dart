import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _serverUrlController;
  late TextEditingController _serverTokenController;
  late TextEditingController _systemPromptController;
  late String _selectedModel;
  bool _apiKeyVisible = false;

  static const _models = [
    ('claude-sonnet-4-5-20250929', 'Claude Sonnet 4.5'),
    ('claude-haiku-4-5-20251001', 'Claude Haiku 4.5'),
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.settings.apiKey);
    _serverUrlController =
        TextEditingController(text: widget.settings.serverUrl);
    _serverTokenController =
        TextEditingController(text: widget.settings.serverToken);
    _systemPromptController =
        TextEditingController(text: widget.settings.systemPrompt);
    _selectedModel = widget.settings.model;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _serverUrlController.dispose();
    _serverTokenController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setApiKey(_apiKeyController.text.trim());
    await widget.settings.setModel(_selectedModel);
    await widget.settings.setServerUrl(_serverUrlController.text.trim());
    await widget.settings.setServerToken(_serverTokenController.text.trim());
    await widget.settings.setSystemPrompt(_systemPromptController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('設定を保存しました'),
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Claude API Section
                _buildSectionTitle('Claude API'),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: !_apiKeyVisible,
                  decoration: InputDecoration(
                    labelText: 'Anthropic API Key',
                    hintText: 'sk-ant-...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _apiKeyVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _apiKeyVisible = !_apiKeyVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration: const InputDecoration(
                    labelText: 'モデル',
                    border: OutlineInputBorder(),
                  ),
                  items: _models
                      .map((m) => DropdownMenuItem(
                            value: m.$1,
                            child: Text(m.$2),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedModel = value);
                    }
                  },
                ),

                const SizedBox(height: 32),

                // System Prompt
                _buildSectionTitle('システムプロンプト'),
                const SizedBox(height: 12),
                TextField(
                  controller: _systemPromptController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'デフォルトのシステムプロンプト',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: 'デフォルトに戻す',
                      onPressed: () {
                        _systemPromptController.text =
                            SettingsService.defaultSystemPrompt;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Server Section
                _buildSectionTitle('Grow サーバー (オプション)'),
                const SizedBox(height: 4),
                Text(
                  '栽培データの同期や共有栽培情報DBに接続します',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverUrlController,
                  decoration: const InputDecoration(
                    labelText: 'サーバーURL',
                    hintText: 'https://your-server.workers.dev',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _serverTokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '認証トークン',
                    hintText: 'Bearer token',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 32),

                // Theme Section
                _buildSectionTitle('表示'),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('システム'),
                      icon: Icon(Icons.settings_brightness),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('ライト'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('ダーク'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {ThemeMode.system},
                  onSelectionChanged: (values) {
                    widget.onThemeModeChanged(values.first);
                  },
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
