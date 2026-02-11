import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/record.dart';
import '../models/record_photo.dart';
import '../services/database_service.dart';
import '../services/site_service.dart';
import '../screens/settings_screen.dart';

const kCfAccountIdPref = 'cf_account_id';
const kCfApiTokenPref = 'cf_api_token';
const kCfProjectNamePref = 'cf_project_name';
const kFarmNamePref = 'farm_name';
const kFarmDescPref = 'farm_description';
const kFarmLocationPref = 'farm_location';
const kFarmPolicyPref = 'farm_policy';
const kSalesDescPref = 'sales_description';
const kSalesContactPref = 'sales_contact';

/// ホームページ作成・デプロイ画面
class SiteScreen extends StatefulWidget {
  final DatabaseService db;
  final Crop? initialCrop;

  const SiteScreen({super.key, required this.db, this.initialCrop});

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen> {
  // 農園情報
  final _farmNameCtrl = TextEditingController();
  final _farmDescCtrl = TextEditingController();
  final _farmLocationCtrl = TextEditingController();
  final _farmPolicyCtrl = TextEditingController();

  // 販売情報
  final _salesDescCtrl = TextEditingController();
  final _salesContactCtrl = TextEditingController();

  // Cloudflare 設定
  final _cfAccountIdCtrl = TextEditingController();
  final _cfApiTokenCtrl = TextEditingController();
  final _cfProjectNameCtrl = TextEditingController();

  // 作物選択
  List<Crop> _allCrops = [];
  Set<String> _selectedCropIds = {};
  Map<String, List<RecordPhoto>> _cropPhotos = {};

  bool _loading = true;
  bool _generating = false;
  bool _deploying = false;
  String? _generatedHtml;
  String? _deployedUrl;

  String _serverUrl = '';
  String _serverToken = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _farmNameCtrl.dispose();
    _farmDescCtrl.dispose();
    _farmLocationCtrl.dispose();
    _farmPolicyCtrl.dispose();
    _salesDescCtrl.dispose();
    _salesContactCtrl.dispose();
    _cfAccountIdCtrl.dispose();
    _cfApiTokenCtrl.dispose();
    _cfProjectNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final crops = await widget.db.getCrops();

    // 作物ごとの写真を取得
    final photosMap = <String, List<RecordPhoto>>{};
    for (final crop in crops) {
      final records = await widget.db.getRecords(cropId: crop.id);
      final photos = <RecordPhoto>[];
      for (final rec in records) {
        photos.addAll(await widget.db.getPhotos(rec.id));
      }
      if (photos.isNotEmpty) {
        photosMap[crop.id] = photos;
      }
    }

    if (!mounted) return;
    setState(() {
      _allCrops = crops;
      _cropPhotos = photosMap;
      _farmNameCtrl.text = prefs.getString(kFarmNamePref) ?? '';
      _farmDescCtrl.text = prefs.getString(kFarmDescPref) ?? '';
      _farmLocationCtrl.text = prefs.getString(kFarmLocationPref) ?? '';
      _farmPolicyCtrl.text = prefs.getString(kFarmPolicyPref) ?? '';
      _salesDescCtrl.text = prefs.getString(kSalesDescPref) ?? '';
      _salesContactCtrl.text = prefs.getString(kSalesContactPref) ?? '';
      _cfAccountIdCtrl.text = prefs.getString(kCfAccountIdPref) ?? '';
      _cfApiTokenCtrl.text = prefs.getString(kCfApiTokenPref) ?? '';
      _cfProjectNameCtrl.text = prefs.getString(kCfProjectNamePref) ?? '';
      _serverUrl = prefs.getString(kServerUrlPref) ?? '';
      _serverToken = prefs.getString(kServerTokenPref) ?? '';

      // 初期選択: 指定された作物 or 写真がある作物全部
      if (widget.initialCrop != null) {
        _selectedCropIds = {widget.initialCrop!.id};
      } else {
        _selectedCropIds = photosMap.keys.toSet();
      }

      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kFarmNamePref, _farmNameCtrl.text);
    await prefs.setString(kFarmDescPref, _farmDescCtrl.text);
    await prefs.setString(kFarmLocationPref, _farmLocationCtrl.text);
    await prefs.setString(kFarmPolicyPref, _farmPolicyCtrl.text);
    await prefs.setString(kSalesDescPref, _salesDescCtrl.text);
    await prefs.setString(kSalesContactPref, _salesContactCtrl.text);
    await prefs.setString(kCfAccountIdPref, _cfAccountIdCtrl.text);
    await prefs.setString(kCfApiTokenPref, _cfApiTokenCtrl.text);
    await prefs.setString(kCfProjectNamePref, _cfProjectNameCtrl.text);
  }

  SiteData _buildSiteData() {
    final selectedCrops = _allCrops
        .where((c) => _selectedCropIds.contains(c.id))
        .map((crop) {
      final photos = _cropPhotos[crop.id] ?? [];
      return SiteCrop(
        cultivationName: crop.cultivationName,
        variety: crop.variety,
        description: crop.memo,
        photoUrls: photos
            .where((p) => p.r2Key != null && p.r2Key!.isNotEmpty)
            .map((p) => '/photos/${p.r2Key}')
            .toList(),
      );
    }).toList();

    return SiteData(
      farmName: _farmNameCtrl.text.trim(),
      farmDescription: _farmDescCtrl.text.trim(),
      farmLocation: _farmLocationCtrl.text.trim(),
      farmPolicy: _farmPolicyCtrl.text.trim(),
      crops: selectedCrops,
      sales: SiteSales(
        description: _salesDescCtrl.text.trim(),
        contact: _salesContactCtrl.text.trim(),
      ),
    );
  }

  Future<void> _generate() async {
    if (_farmNameCtrl.text.trim().isEmpty) {
      _showError('農園名を入力してください');
      return;
    }
    if (_serverUrl.isEmpty || _serverToken.isEmpty) {
      _showError('サーバー設定が必要です（システム設定から設定してください）');
      return;
    }

    await _savePrefs();
    setState(() => _generating = true);

    try {
      final service = SiteService(
        serverUrl: _serverUrl,
        serverToken: _serverToken,
      );
      final html = await service.generateHtml(_buildSiteData());
      if (!mounted) return;
      setState(() {
        _generatedHtml = html;
        _generating = false;
      });
      _showSuccess('HTMLを生成しました');
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showError(e.toString());
    }
  }

  Future<void> _deploy() async {
    final accountId = _cfAccountIdCtrl.text.trim();
    final apiToken = _cfApiTokenCtrl.text.trim();
    final projectName = _cfProjectNameCtrl.text.trim();

    if (accountId.isEmpty || apiToken.isEmpty || projectName.isEmpty) {
      _showError('Cloudflare の設定を全て入力してください');
      return;
    }
    if (_serverUrl.isEmpty || _serverToken.isEmpty) {
      _showError('サーバー設定が必要です');
      return;
    }

    await _savePrefs();
    setState(() => _deploying = true);

    try {
      final service = SiteService(
        serverUrl: _serverUrl,
        serverToken: _serverToken,
      );
      final result = await service.deploy(
        site: _buildSiteData(),
        cfAccountId: accountId,
        cfApiToken: apiToken,
        projectName: projectName,
      );
      if (!mounted) return;
      setState(() {
        _deployedUrl = result.projectUrl;
        _deploying = false;
      });
      _showSuccess('デプロイ完了: ${result.projectUrl}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deploying = false);
      _showError(e.toString());
    }
  }

  void _copyHtml() {
    if (_generatedHtml == null) return;
    Clipboard.setData(ClipboardData(text: _generatedHtml!));
    _showSuccess('HTMLをクリップボードにコピーしました');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.createHomepage)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(l.siteInfoFarm),
                _buildTextField(_farmNameCtrl, l.siteFarmName, required: true),
                _buildTextField(_farmDescCtrl, l.siteFarmDesc, maxLines: 3),
                _buildTextField(_farmLocationCtrl, l.siteFarmLocation),
                _buildTextField(_farmPolicyCtrl, l.siteFarmPolicy),
                const SizedBox(height: 24),

                _buildSectionHeader(l.siteInfoCrops),
                _buildCropSelector(),
                const SizedBox(height: 24),

                _buildSectionHeader(l.siteInfoSales),
                _buildTextField(_salesDescCtrl, l.siteSalesDesc, maxLines: 3),
                _buildTextField(_salesContactCtrl, l.siteSalesContact,
                    maxLines: 2),
                const SizedBox(height: 24),

                // 生成ボタン
                FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.code),
                  label: Text(l.siteGenerate),
                ),

                if (_generatedHtml != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.siteHtmlReady,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _copyHtml,
                                icon: const Icon(Icons.copy, size: 18),
                                label: Text(l.siteCopyHtml),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                _buildSectionHeader(l.siteDeploySection),
                Text(l.siteDeployDesc,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                _buildTextField(_cfAccountIdCtrl, l.siteCfAccountId),
                _buildTextField(_cfApiTokenCtrl, l.siteCfApiToken,
                    obscure: true),
                _buildTextField(_cfProjectNameCtrl, l.siteCfProjectName),
                const SizedBox(height: 12),

                FilledButton.icon(
                  onPressed: _deploying ? null : _deploy,
                  icon: _deploying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(l.siteDeploy),
                ),

                if (_deployedUrl != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.check_circle),
                      title: Text(l.siteDeployDone),
                      subtitle: Text(_deployedUrl!),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () async {
                        final uri = Uri.tryParse(_deployedUrl!);
                        if (uri != null) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    bool obscure = false,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        maxLines: obscure ? 1 : maxLines,
        obscureText: obscure,
      ),
    );
  }

  Widget _buildCropSelector() {
    if (_allCrops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('栽培がまだありません'),
      );
    }

    return Column(
      children: _allCrops.map((crop) {
        final photoCount = _cropPhotos[crop.id]?.length ?? 0;
        final synced = _cropPhotos[crop.id]
                ?.where((p) => p.r2Key != null && p.r2Key!.isNotEmpty)
                .length ??
            0;
        return CheckboxListTile(
          value: _selectedCropIds.contains(crop.id),
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedCropIds.add(crop.id);
              } else {
                _selectedCropIds.remove(crop.id);
              }
            });
          },
          title: Text(crop.cultivationName),
          subtitle: Text(
            '${crop.variety.isNotEmpty ? crop.variety : ""}'
            '${photoCount > 0 ? " ($synced/$photoCount枚同期済)" : ""}',
          ),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }
}
