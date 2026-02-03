import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../services/database_service.dart';

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
  Map<String, List<String>> _cropPlotIds = {};
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
    final cropPlotIds = <String, List<String>>{};
    for (final crop in crops) {
      cropPlotIds[crop.id] = await widget.db.getCropPlotIds(crop.id);
    }
    if (!mounted) return;
    setState(() {
      _crops = crops;
      _allPlots = allPlots;
      _locations = locations;
      _cropPlotIds = cropPlotIds;
      _loading = false;
    });
  }

  String _plotName(String plotId) {
    final plot = _allPlots.where((p) => p.id == plotId).firstOrNull;
    if (plot == null) return '';
    final loc = _locations.where((l) => l.id == plot.locationId).firstOrNull;
    return loc != null ? '${loc.name} / ${plot.name}' : plot.name;
  }

  Future<void> _showForm({Crop? existing}) async {
    final l = AppLocalizations.of(context)!;

    final cultivationNameCtrl =
        TextEditingController(text: existing?.cultivationName ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final varietyCtrl = TextEditingController(text: existing?.variety ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');

    // Load linked plot IDs for editing
    List<String> selectedPlotIds = [];
    if (existing != null) {
      selectedPlotIds =
          List.of(await widget.db.getCropPlotIds(existing.id));
    }

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
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.linkedPlots,
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._allPlots.map((plot) {
                      final checked = selectedPlotIds.contains(plot.id);
                      final loc = _locations
                          .where((lo) => lo.id == plot.locationId)
                          .firstOrNull;
                      final label = loc != null
                          ? '${loc.name} / ${plot.name}'
                          : plot.name;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(label),
                        value: checked,
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selectedPlotIds.add(plot.id);
                            } else {
                              selectedPlotIds.remove(plot.id);
                            }
                          });
                        },
                      );
                    }),
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
      memo: memoCtrl.text.trim(),
      startDate: existing?.startDate,
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertCrop(crop);
    } else {
      await widget.db.updateCrop(crop);
    }

    // Save crop-plot links
    await widget.db.setCropPlots(crop.id, selectedPlotIds);

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
                    final plotIds = _cropPlotIds[crop.id] ?? [];
                    final plotNames =
                        plotIds.map((id) => _plotName(id)).where((s) => s.isNotEmpty);
                    final subtitle = [
                      if (crop.name.isNotEmpty) crop.name,
                      if (crop.variety.isNotEmpty) crop.variety,
                      ...plotNames,
                    ].join(' / ');

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.eco),
                        title: Text(crop.cultivationName),
                        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                        onTap: () => _showForm(existing: crop),
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
