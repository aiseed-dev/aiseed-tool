import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../models/record.dart';
import '../models/record_photo.dart';
import '../services/database_service.dart';

class CropDetailScreen extends StatefulWidget {
  final DatabaseService db;
  final Crop crop;

  const CropDetailScreen({super.key, required this.db, required this.crop});

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> {
  late Crop _crop;
  List<_RecordWithPhotos> _timeline = [];
  List<Crop> _allCrops = [];
  List<Plot> _allPlots = [];
  List<Location> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _crop = widget.crop;
    _load();
  }

  Future<void> _load() async {
    final allCrops = await widget.db.getCrops();
    final allPlots = await widget.db.getAllPlots();
    final locations = await widget.db.getLocations();

    // Reload crop from DB in case it was edited
    final freshCrop = allCrops.where((c) => c.id == _crop.id).firstOrNull;
    if (freshCrop != null) _crop = freshCrop;

    final records = await widget.db.getRecords(cropId: _crop.id);
    final timeline = <_RecordWithPhotos>[];
    for (final rec in records) {
      final photos = await widget.db.getPhotos(rec.id);
      timeline.add(_RecordWithPhotos(record: rec, photos: photos));
    }
    if (!mounted) return;
    setState(() {
      _allCrops = allCrops;
      _allPlots = allPlots;
      _locations = locations;
      _timeline = timeline;
      _loading = false;
    });
  }

  String _activityLabel(AppLocalizations l, ActivityType type) {
    switch (type) {
      case ActivityType.sowing:
        return l.activitySowing;
      case ActivityType.transplanting:
        return l.activityTransplanting;
      case ActivityType.watering:
        return l.activityWatering;
      case ActivityType.observation:
        return l.activityObservation;
      case ActivityType.harvest:
        return l.activityHarvest;
      case ActivityType.other:
        return l.activityOther;
    }
  }

  String _plotDisplayName(String? plotId) {
    if (plotId == null) return '';
    final plot = _allPlots.where((p) => p.id == plotId).firstOrNull;
    if (plot == null) return '';
    final loc = _locations.where((l) => l.id == plot.locationId).firstOrNull;
    return loc != null ? '${loc.name} / ${plot.name}' : plot.name;
  }

  Future<void> _editCrop() async {
    final l = AppLocalizations.of(context)!;
    final cultivationNameCtrl =
        TextEditingController(text: _crop.cultivationName);
    final nameCtrl = TextEditingController(text: _crop.name);
    final varietyCtrl = TextEditingController(text: _crop.variety);
    final memoCtrl = TextEditingController(text: _crop.memo);

    String? selectedPlotId = _crop.plotId;
    String? selectedParentCropId = _crop.parentCropId;

    final parentCandidates =
        _allCrops.where((c) => c.id != _crop.id).toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l.editCrop),
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

    final updated = Crop(
      id: _crop.id,
      cultivationName: cultivationNameCtrl.text.trim(),
      name: nameCtrl.text.trim(),
      variety: varietyCtrl.text.trim(),
      plotId: selectedPlotId,
      parentCropId: selectedParentCropId,
      memo: memoCtrl.text.trim(),
      startDate: _crop.startDate,
      createdAt: _crop.createdAt,
    );

    await widget.db.updateCrop(updated);
    _load();
  }

  Widget _buildCropInfo(AppLocalizations l) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _crop.cultivationName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _editCrop,
                ),
              ],
            ),
            if (_crop.name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 28),
                  Text('${l.cropName}: ${_crop.name}'),
                ],
              ),
            ],
            if (_crop.variety.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 28),
                  Text('${l.variety}: ${_crop.variety}'),
                ],
              ),
            ],
            if (_crop.plotId != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.grid_view, size: 16),
                  const SizedBox(width: 6),
                  Text(_plotDisplayName(_crop.plotId)),
                ],
              ),
            ],
            if (_crop.memo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_crop.memo)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${l.date}: ${_crop.startDate.year}/${_crop.startDate.month.toString().padLeft(2, '0')}/${_crop.startDate.day.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomepageLink(AppLocalizations l) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        leading: const Icon(Icons.web),
        title: Text(l.createHomepage),
        subtitle: Text(l.createHomepageDesc),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.homepageComingSoon)),
          );
        },
      ),
    );
  }

  Widget _buildTimeline(AppLocalizations l) {
    if (_timeline.isEmpty) {
      return Expanded(
        child: Center(child: Text(l.noRecords)),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _timeline.length,
        itemBuilder: (context, index) {
          final item = _timeline[index];
          final rec = item.record;
          final dateStr =
              '${rec.date.year}/${rec.date.month.toString().padLeft(2, '0')}/${rec.date.day.toString().padLeft(2, '0')}';
          final actLabel = _activityLabel(l, rec.activityType);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and activity type header
                  Row(
                    children: [
                      Icon(
                        _activityIcon(rec.activityType),
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$dateStr - $actLabel',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  // Note
                  if (rec.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(rec.note),
                  ],
                  // Photos
                  if (item.photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.photos.length,
                        itemBuilder: (context, photoIndex) {
                          final photo = item.photos[photoIndex];
                          final file = File(photo.filePath);
                          return Padding(
                            padding: EdgeInsets.only(
                              right:
                                  photoIndex < item.photos.length - 1 ? 8 : 0,
                            ),
                            child: GestureDetector(
                              onTap: () => _showPhotoFullScreen(photo),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: file.existsSync()
                                    ? Image.file(
                                        file,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 200,
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 48,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.sowing:
        return Icons.grass;
      case ActivityType.transplanting:
        return Icons.move_down;
      case ActivityType.watering:
        return Icons.water_drop;
      case ActivityType.observation:
        return Icons.visibility;
      case ActivityType.harvest:
        return Icons.agriculture;
      case ActivityType.other:
        return Icons.more_horiz;
    }
  }

  void _showPhotoFullScreen(RecordPhoto photo) {
    final file = File(photo.filePath);
    if (!file.existsSync()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_crop.cultivationName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCropInfo(l),
                _buildHomepageLink(l),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        l.growthTimeline,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                _buildTimeline(l),
              ],
            ),
    );
  }
}

class _RecordWithPhotos {
  final GrowRecord record;
  final List<RecordPhoto> photos;

  _RecordWithPhotos({required this.record, required this.photos});
}
