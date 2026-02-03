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
  List<Location> _locations = [];
  Map<String, List<Plot>> _plotsByLocation = {};
  String? _selectedLocationId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locations = await widget.db.getLocations();
    final plotsByLocation = <String, List<Plot>>{};
    for (final loc in locations) {
      plotsByLocation[loc.id] = await widget.db.getPlots(loc.id);
    }
    final crops = await widget.db.getCrops(locationId: _selectedLocationId);
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _plotsByLocation = plotsByLocation;
      _crops = crops;
      _loading = false;
    });
  }

  String _locationName(String locationId) {
    final loc = _locations.where((l) => l.id == locationId).firstOrNull;
    return loc?.name ?? '';
  }

  String _plotName(String? plotId) {
    if (plotId == null) return '';
    for (final plots in _plotsByLocation.values) {
      final plot = plots.where((p) => p.id == plotId).firstOrNull;
      if (plot != null) return plot.name;
    }
    return '';
  }

  Future<void> _showForm({Crop? existing}) async {
    final l = AppLocalizations.of(context)!;

    if (_locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noLocations)),
      );
      return;
    }

    final cultivationNameCtrl =
        TextEditingController(text: existing?.cultivationName ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final varietyCtrl = TextEditingController(text: existing?.variety ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    var selectedLocationId = existing?.locationId ?? _locations.first.id;
    String? selectedPlotId = existing?.plotId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final plots = _plotsByLocation[selectedLocationId] ?? [];
          // Reset plotId if it doesn't belong to selected location
          if (selectedPlotId != null &&
              !plots.any((p) => p.id == selectedPlotId)) {
            selectedPlotId = null;
          }

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
                  DropdownButtonFormField<String>(
                    value: selectedLocationId,
                    decoration: InputDecoration(labelText: l.selectLocation),
                    items: _locations
                        .map((loc) => DropdownMenuItem(
                              value: loc.id,
                              child: Text(loc.name),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedLocationId = v!;
                        selectedPlotId = null;
                      });
                    },
                  ),
                  if (plots.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: selectedPlotId,
                      decoration:
                          InputDecoration(labelText: l.selectPlot),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l.nonePlot),
                        ),
                        ...plots.map((plot) => DropdownMenuItem<String?>(
                              value: plot.id,
                              child: Text(plot.name),
                            )),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedPlotId = v),
                    ),
                  ],
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
      locationId: selectedLocationId,
      plotId: selectedPlotId,
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
      appBar: AppBar(
        title: Text(l.crops),
        actions: [
          if (_locations.isNotEmpty)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              onSelected: (v) {
                _selectedLocationId = v;
                _load();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: null,
                  child: Text(l.allLocations),
                ),
                ..._locations.map((loc) => PopupMenuItem(
                      value: loc.id,
                      child: Text(loc.name),
                    )),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _crops.isEmpty
              ? Center(child: Text(l.noCrops))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _crops.length,
                  itemBuilder: (context, index) {
                    final crop = _crops[index];
                    final plotStr = _plotName(crop.plotId);
                    final subtitle = [
                      if (crop.name.isNotEmpty) crop.name,
                      if (crop.variety.isNotEmpty) crop.variety,
                      _locationName(crop.locationId),
                      if (plotStr.isNotEmpty) plotStr,
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
