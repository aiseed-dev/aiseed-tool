import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/skill_file_generator.dart';

const kSkillFileKey = 'generated_skill_file';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  static const _totalSteps = 5;

  // Q1: Crops
  final _cropsController = TextEditingController();
  final _selectedCrops = <String>[];
  static const _commonCrops = [
    'トマト', 'ナス', 'キュウリ', 'ピーマン', 'オクラ',
    'レタス', 'ホウレンソウ', 'ダイコン', 'ニンジン', 'ジャガイモ',
    'タマネギ', 'ネギ', 'キャベツ', 'ブロッコリー', 'エダマメ',
    'イチゴ', 'ハーブ類', 'バジル', 'パセリ', '果樹',
  ];

  // Q2: Location
  final _locationController = TextEditingController();

  // Q3: Farming method
  String _farmingMethod = '';

  // Q4: Experience
  String _experience = '';

  // Q5: Challenges
  final _challengesController = TextEditingController();

  // Result
  String? _generatedSkillFile;

  @override
  void dispose() {
    _cropsController.dispose();
    _locationController.dispose();
    _challengesController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _selectedCrops.isNotEmpty ||
            _cropsController.text.trim().isNotEmpty;
      case 1:
        return _locationController.text.trim().isNotEmpty;
      case 2:
        return _farmingMethod.isNotEmpty;
      case 3:
        return _experience.isNotEmpty;
      case 4:
        return true; // optional
      default:
        return false;
    }
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _generate();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  void _generate() {
    final customCrops = _cropsController.text
        .trim()
        .split(RegExp(r'[,、\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final allCrops = [..._selectedCrops, ...customCrops];

    final profile = GrowProfile(
      crops: allCrops,
      location: _locationController.text.trim(),
      farmingMethod: _farmingMethod,
      experience: _experience,
      challenges: _challengesController.text.trim(),
    );

    setState(() {
      _generatedSkillFile = SkillFileGenerator.generate(profile);
      _step = _totalSteps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('あなた専用のAI設定をつくる'),
      ),
      body: _step < _totalSteps ? _buildQuestion() : _buildResult(),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            'Q${_step + 1} / $_totalSteps',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildStepContent()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_step > 0)
                TextButton.icon(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('戻る'),
                )
              else
                const SizedBox.shrink(),
              FilledButton.icon(
                onPressed: _canProceed ? _next : null,
                icon: Icon(_step == _totalSteps - 1
                    ? Icons.auto_awesome
                    : Icons.arrow_forward),
                label:
                    Text(_step == _totalSteps - 1 ? 'スキルファイルを生成' : '次へ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildCropsStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildMethodStep();
      case 3:
        return _buildExperienceStep();
      case 4:
        return _buildChallengesStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCropsStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('何を育てていますか？',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('当てはまるものをタップ、または入力してください',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonCrops.map((crop) {
              final selected = _selectedCrops.contains(crop);
              return FilterChip(
                label: Text(crop),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedCrops.add(crop);
                    } else {
                      _selectedCrops.remove(crop);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cropsController,
            decoration: const InputDecoration(
              labelText: 'その他の作物（カンマ区切り）',
              hintText: 'ズッキーニ、アーティチョーク',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('どこで育てていますか？',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('地域や環境を教えてください',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: '栽培場所',
            hintText: '例: 神奈川県・庭の菜園、ベランダのプランター',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildMethodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('農法は？', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('どのようなスタイルで栽培していますか？',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        ...SkillFileGenerator.farmingMethods.entries.map((e) {
          return RadioListTile<String>(
            value: e.key,
            groupValue: _farmingMethod,
            title: Text(e.value),
            onChanged: (v) => setState(() => _farmingMethod = v ?? ''),
          );
        }),
      ],
    );
  }

  Widget _buildExperienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('経験年数は？', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ...SkillFileGenerator.experienceLevels.entries.map((e) {
          return RadioListTile<String>(
            value: e.key,
            groupValue: _experience,
            title: Text(e.value),
            onChanged: (v) => setState(() => _experience = v ?? ''),
          );
        }),
      ],
    );
  }

  Widget _buildChallengesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('困っていることは？',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('今一番知りたいこと、困っていることを教えてください（任意）',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        TextField(
          controller: _challengesController,
          decoration: const InputDecoration(
            labelText: '現在の課題',
            hintText: '例: 害虫対策、土づくり、収穫量を上げたい',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.auto_awesome,
                  size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text('あなた専用のスキルファイルが完成しました！',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('このMarkdownをAIの設定に貼り付けてください',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('コピー'),
              ),
              OutlinedButton.icon(
                onPressed: _saveToFile,
                icon: const Icon(Icons.download),
                label: const Text('ファイル保存'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Markdown(
                data: _generatedSkillFile ?? '',
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard() {
    if (_generatedSkillFile == null) return;
    Clipboard.setData(ClipboardData(text: _generatedSkillFile!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('スキルファイルをクリップボードにコピーしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveToFile() async {
    if (_generatedSkillFile == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final file = File('${dir.path}/grow_skill_$timestamp.md');
      await file.writeAsString(_generatedSkillFile!);

      // Also save to SharedPreferences for later viewing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kSkillFileKey, _generatedSkillFile!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存しました: ${file.path}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }
}
