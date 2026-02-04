import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../services/database_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _showForm({Crop? existing}) async {
    final l = AppLocalizations.of(context)!;

    final cultivationNameCtrl =
        TextEditingController(text: existing?.cultivationName ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final varietyCtrl = TextEditingController(text: existing?.variety ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');

    String? selectedPlotId = existing?.plotId;
    String? selectedParentCropId = existing?.parentCropId;

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
      memo: memoCtrl.text.trim(),
      startDate: existing?.startDate,
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertCrop(crop);
    } else {
      await widget.db.updateCrop(crop);
    }

    _load();
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

    return Scaffold(
      appBar: AppBar(title: Text(l.crops)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _crops.isEmpty
              ? Center(child: Text(l.noCrops))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _crops.length,
                  itemBuilder: (context, index) {
                    final crop = _crops[index];
                    final plotName = _plotDisplayName(crop.plotId);
                    final parentName = _parentCropName(crop.parentCropId);
                    final subtitle = [
                      if (crop.name.isNotEmpty) crop.name,
                      if (crop.variety.isNotEmpty) crop.variety,
                      if (plotName.isNotEmpty) plotName,
                      if (parentName.isNotEmpty) '← $parentName',
                    ].join(' / ');

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.eco),
                        title: Text(crop.cultivationName),
                        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                        onTap: () => _openCropDetail(crop),
                        onLongPress: () => _showForm(existing: crop),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(crop),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
