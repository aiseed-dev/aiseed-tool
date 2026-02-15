import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../services/database_service.dart';
import '../services/skill_file_generator.dart';
import 'crop_create_screen.dart';
import 'crop_detail_screen.dart';

class CropsScreen extends StatefulWidget {
  final DatabaseService db;

  const CropsScreen({super.key, required this.db});

  @override
  State<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends State<CropsScreen> {
  List<Crop> _crops = [];
  List<Plot> _allPlots = [];
  List<Location> _locations = [];
  bool _loading = true;

  // 検索・フィルタ
  bool _isSearching = false;
  String _searchQuery = '';
  bool _showEnded = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final crops = await widget.db.getCrops();
    final allPlots = await widget.db.getAllPlots();
    final locations = await widget.db.getLocations();
    if (!mounted) return;
    setState(() {
      _crops = crops;
      _allPlots = allPlots;
      _locations = locations;
      _loading = false;
    });
  }

  List<Crop> get _filteredCrops {
    var results = _crops;

    // 終了した栽培を除外（デフォルト）
    if (!_showEnded) {
      results = results.where((c) => !c.isEnded).toList();
    }

    // 検索
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((c) {
        if (c.cultivationName.toLowerCase().contains(query)) return true;
        if (c.name.toLowerCase().contains(query)) return true;
        if (c.variety.toLowerCase().contains(query)) return true;
        if (c.memo.toLowerCase().contains(query)) return true;
        return false;
      }).toList();
    }

    return results;
  }

  String _plotDisplayName(String? plotId) {
    if (plotId == null) return '';
    final plot = _allPlots.where((p) => p.id == plotId).firstOrNull;
    if (plot == null) return '';
    final loc = _locations.where((l) => l.id == plot.locationId).firstOrNull;
    return loc != null ? '${loc.name} / ${plot.name}' : plot.name;
  }

  String _parentCropName(String? parentCropId) {
    if (parentCropId == null) return '';
    final crop = _crops.where((c) => c.id == parentCropId).firstOrNull;
    return crop?.cultivationName ?? '';
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showForm({Crop? existing}) async {
    final l = AppLocalizations.of(context)!;

    final cultivationNameCtrl =
        TextEditingController(text: existing?.cultivationName ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final varietyCtrl = TextEditingController(text: existing?.variety ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');

    String? selectedPlotId = existing?.plotId;
    String? selectedParentCropId = existing?.parentCropId;
    String? selectedFarmingMethod = existing?.farmingMethod;
    DateTime? endDate = existing?.endDate;

    // Crops available as parent (exclude self)
    final parentCandidates =
        _crops.where((c) => c.id != existing?.id).toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? l.addCrop : l.editCrop),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: cultivationNameCtrl,
                    decoration:
                        InputDecoration(labelText: l.cultivationName),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: l.cropName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: varietyCtrl,
                    decoration: InputDecoration(labelText: l.variety),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: memoCtrl,
                    decoration: InputDecoration(labelText: l.memo),
                    maxLines: 3,
                  ),
                  if (_allPlots.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedPlotId,
                      decoration: InputDecoration(labelText: l.selectPlot),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l.nonePlot),
                        ),
                        ..._allPlots.map((plot) {
                          final loc = _locations
                              .where((lo) => lo.id == plot.locationId)
                              .firstOrNull;
                          final label = loc != null
                              ? '${loc.name} / ${plot.name}'
                              : plot.name;
                          return DropdownMenuItem<String?>(
                            value: plot.id,
                            child: Text(label),
                          );
                        }),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedPlotId = v),
                    ),
                  ],
                  if (parentCandidates.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedParentCropId,
                      decoration:
                          InputDecoration(labelText: l.parentCrop),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l.nonePlot),
                        ),
                        ...parentCandidates.map((c) =>
                            DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.cultivationName),
                            )),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedParentCropId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFarmingMethod,
                    decoration:
                        InputDecoration(labelText: l.farmingMethod),
                    items: SkillFileGenerator.farmingMethods.entries
                        .map((e) => DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedFarmingMethod = v);
                      }
                    },
                  ),
                  // 終了日
                  if (existing != null) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available),
                      title: Text(endDate != null
                          ? '終了: ${_formatDate(endDate!)}'
                          : '栽培中'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () =>
                                  setDialogState(() => endDate = null),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today, size: 20),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() => endDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
          );
        },
      ),
    );

    if (saved != true || cultivationNameCtrl.text.trim().isEmpty) return;

    final crop = Crop(
      id: existing?.id,
      cultivationName: cultivationNameCtrl.text.trim(),
      name: nameCtrl.text.trim(),
      variety: varietyCtrl.text.trim(),
      plotId: selectedPlotId,
      parentCropId: selectedParentCropId,
      farmingMethod: selectedFarmingMethod,
      memo: memoCtrl.text.trim(),
      startDate: existing?.startDate,
      endDate: endDate,
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertCrop(crop);
    } else {
      await widget.db.updateCrop(crop);
    }

    _load();
  }

  void _showCropMenu(Crop crop) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.editCrop),
              onTap: () {
                Navigator.pop(ctx);
                _showForm(existing: crop);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
              onTap: () {
                Navigator.pop(ctx);
                _delete(crop);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCropDetail(Crop crop) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropDetailScreen(db: widget.db, crop: crop),
      ),
    );
    _load();
  }

  Future<void> _delete(Crop crop) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.delete),
        content: Text(l.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.db.deleteCrop(crop.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filtered = _filteredCrops;
    final endedCount = _crops.where((c) => c.isEnded).length;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '栽培を検索...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(l.crops),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 終了済み表示トグル
                if (endedCount > 0)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('終了済みも表示 ($endedCount)'),
                          selected: _showEnded,
                          onSelected: (v) =>
                              setState(() => _showEnded = v),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text(l.noCrops))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final crop = filtered[index];
                            return _buildCropCard(crop);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CropCreateScreen(db: widget.db),
            ),
          );
          if (result == true) _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCropCard(Crop crop) {
    final plotName = _plotDisplayName(crop.plotId);
    final parentName = _parentCropName(crop.parentCropId);
    final methodLabel = crop.farmingMethod != null
        ? SkillFileGenerator.farmingMethods[crop.farmingMethod!] ??
            crop.farmingMethod!
        : null;

    // 日付表示
    final dateStr = crop.isEnded
        ? '${_formatDate(crop.startDate)} ~ ${_formatDate(crop.endDate!)}'
        : '${_formatDate(crop.startDate)} ~';

    final details = [
      if (crop.name.isNotEmpty) crop.name,
      if (crop.variety.isNotEmpty) crop.variety,
      if (plotName.isNotEmpty) plotName,
      if (parentName.isNotEmpty) '← $parentName',
      if (methodLabel != null) methodLabel,
    ].join(' / ');

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.eco,
          color: crop.isEnded
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
        title: Text(
          crop.cultivationName,
          style: crop.isEnded
              ? TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (details.isNotEmpty)
              Text(
                details,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        onTap: () => _openCropDetail(crop),
        onLongPress: () => _showCropMenu(crop),
      ),
    );
  }
}
