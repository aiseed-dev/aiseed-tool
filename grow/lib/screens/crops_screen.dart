import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/location.dart';
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
  String? _selectedLocationId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locations = await widget.db.getLocations();
    final crops = await widget.db.getCrops(locationId: _selectedLocationId);
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _crops = crops;
      _loading = false;
    });
  }

  String _acquisitionLabel(AppLocalizations l, AcquisitionType type) {
    switch (type) {
      case AcquisitionType.seedSowing:
        return l.acquisitionSeedSowing;
      case AcquisitionType.seedlingPurchase:
        return l.acquisitionSeedlingPurchase;
      case AcquisitionType.seedlingTransplant:
        return l.acquisitionSeedlingTransplant;
      case AcquisitionType.directSowing:
        return l.acquisitionDirectSowing;
    }
  }

  String _locationName(String locationId) {
    final loc = _locations.where((l) => l.id == locationId).firstOrNull;
    return loc?.name ?? '';
  }

  Future<void> _showForm({Crop? existing}) async {
    final l = AppLocalizations.of(context)!;

    if (_locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noLocations)),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final varietyCtrl = TextEditingController(text: existing?.variety ?? '');
    var selectedLocationId = existing?.locationId ?? _locations.first.id;
    var selectedAcquisition =
        existing?.acquisitionType ?? AcquisitionType.seedSowing;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? l.addCrop : l.editCrop),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedLocationId,
                  decoration: InputDecoration(labelText: l.selectLocation),
                  items: _locations
                      .map((loc) => DropdownMenuItem(
                            value: loc.id,
                            child: Text(loc.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedLocationId = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l.cropName),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: varietyCtrl,
                  decoration: InputDecoration(labelText: l.variety),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AcquisitionType>(
                  value: selectedAcquisition,
                  decoration: InputDecoration(labelText: l.acquisitionType),
                  items: AcquisitionType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_acquisitionLabel(l, t)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedAcquisition = v!),
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
        ),
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    final crop = Crop(
      id: existing?.id,
      locationId: selectedLocationId,
      name: nameCtrl.text.trim(),
      variety: varietyCtrl.text.trim(),
      acquisitionType: selectedAcquisition,
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
                    final subtitle = [
                      if (crop.variety.isNotEmpty) crop.variety,
                      _acquisitionLabel(l, crop.acquisitionType),
                      _locationName(crop.locationId),
                    ].join(' / ');

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.eco),
                        title: Text(crop.name),
                        subtitle: Text(subtitle),
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
