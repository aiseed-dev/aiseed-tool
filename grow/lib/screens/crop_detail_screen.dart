import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/crop_reference.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../models/record.dart';
import '../models/record_photo.dart';
import '../services/cultivation_info_service.dart';
import '../services/database_service.dart';
import 'site_screen.dart';

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
  List<CropReference> _references = [];
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
    final references = await widget.db.getCropReferences(_crop.id);
    if (!mounted) return;
    setState(() {
      _allCrops = allCrops;
      _allPlots = allPlots;
      _locations = locations;
      _timeline = timeline;
      _references = references;
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
      case ActivityType.pruning:
        return l.activityPruning;
      case ActivityType.weeding:
        return l.activityWeeding;
      case ActivityType.bedMaking:
        return l.activityBedMaking;
      case ActivityType.tilling:
        return l.activityTilling;
      case ActivityType.potUp:
        return l.activityPotUp;
      case ActivityType.cutting:
        return l.activityCutting;
      case ActivityType.flowering:
        return l.activityFlowering;
      case ActivityType.shipping:
        return l.activityShipping;
      case ActivityType.management:
        return l.activityManagement;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
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
      endDate: _crop.endDate,
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
                  Expanded(child: Text('${l.cropName}: ${_crop.name}')),
                ],
              ),
            ],
            if (_crop.variety.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(child: Text('${l.variety}: ${_crop.variety}')),
                ],
              ),
            ],
            if (_crop.plotId != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.grid_view, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_plotDisplayName(_crop.plotId))),
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
                  _crop.isEnded
                      ? '${_formatDate(_crop.startDate)} ~ ${_formatDate(_crop.endDate!)}'
                      : '${_formatDate(_crop.startDate)} ~',
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SiteScreen(
                db: widget.db,
                initialCrop: _crop,
              ),
            ),
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
                      Expanded(
                        child: Text(
                          '$dateStr - $actLabel',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  // 収穫量
                  if (rec.activityType == ActivityType.harvest &&
                      rec.harvestAmount != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.agriculture, size: 16,
                            color: Theme.of(context).colorScheme.tertiary),
                        const SizedBox(width: 4),
                        Text(
                          '収穫量: ${rec.harvestAmount!.toStringAsFixed(rec.harvestAmount! == rec.harvestAmount!.roundToDouble() ? 0 : 1)}${rec.harvestUnit}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // 出荷量・出荷額
                  if (rec.activityType == ActivityType.shipping &&
                      (rec.shippingAmount != null || rec.shippingPrice != null)) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_shipping, size: 16,
                            color: Theme.of(context).colorScheme.tertiary),
                        const SizedBox(width: 4),
                        if (rec.shippingAmount != null)
                          Text(
                            '出荷量: ${rec.shippingAmount!.toStringAsFixed(rec.shippingAmount! == rec.shippingAmount!.roundToDouble() ? 0 : 1)}${rec.shippingUnit}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (rec.shippingAmount != null && rec.shippingPrice != null)
                          const Text('  '),
                        if (rec.shippingPrice != null)
                          Text(
                            '¥${rec.shippingPrice!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
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
      case ActivityType.pruning:
        return Icons.content_cut;
      case ActivityType.weeding:
        return Icons.eco;
      case ActivityType.bedMaking:
        return Icons.landscape;
      case ActivityType.tilling:
        return Icons.handyman;
      case ActivityType.potUp:
        return Icons.yard;
      case ActivityType.cutting:
        return Icons.carpenter;
      case ActivityType.flowering:
        return Icons.local_florist;
      case ActivityType.shipping:
        return Icons.local_shipping;
      case ActivityType.management:
        return Icons.settings;
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
                if (_references.isNotEmpty) _buildReferences(l),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addRecord(l),
        child: const Icon(Icons.add),
      ),
    );
  }

  static const _units = ['kg', 'g', '個', '本', '束', '袋', 'パック'];

  Future<void> _addRecord(AppLocalizations l) async {
    var selectedActivity = ActivityType.observation;
    var selectedDate = DateTime.now();
    final noteCtrl = TextEditingController();
    // 収穫
    final harvestAmountCtrl = TextEditingController();
    var harvestUnit = 'kg';
    // 出荷
    final shippingAmountCtrl = TextEditingController();
    var shippingUnit = 'kg';
    final shippingPriceCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.addRecord),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 活動タイプ
                DropdownButtonFormField<ActivityType>(
                  value: selectedActivity,
                  decoration: InputDecoration(labelText: l.activityType),
                  items: ActivityType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(_activityLabel(l, t)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedActivity = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // 日付
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    '${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                // 収穫量（収穫時のみ）
                if (selectedActivity == ActivityType.harvest) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: harvestAmountCtrl,
                          decoration: const InputDecoration(labelText: '収穫量'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: harvestUnit,
                          decoration: const InputDecoration(labelText: '単位'),
                          items: _units
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => harvestUnit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                // 出荷量・出荷額（出荷時のみ）
                if (selectedActivity == ActivityType.shipping) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: shippingAmountCtrl,
                          decoration: const InputDecoration(labelText: '出荷量'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: shippingUnit,
                          decoration: const InputDecoration(labelText: '単位'),
                          items: _units
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => shippingUnit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shippingPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: '出荷額（円）',
                      prefixText: '¥',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                // メモ
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(labelText: l.note),
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
        ),
      ),
    );

    if (saved != true) return;

    final record = GrowRecord(
      cropId: _crop.id,
      activityType: selectedActivity,
      date: selectedDate,
      note: noteCtrl.text.trim(),
      harvestAmount: selectedActivity == ActivityType.harvest
          ? double.tryParse(harvestAmountCtrl.text)
          : null,
      harvestUnit: harvestUnit,
      shippingAmount: selectedActivity == ActivityType.shipping
          ? double.tryParse(shippingAmountCtrl.text)
          : null,
      shippingUnit: shippingUnit,
      shippingPrice: selectedActivity == ActivityType.shipping
          ? int.tryParse(shippingPriceCtrl.text)
          : null,
    );
    await widget.db.insertRecord(record);
    _load();
  }

  Widget _buildReferences(AppLocalizations l) {
    final seedPhotos =
        _references.where((r) => r.type == CropReferenceType.seedPhoto).toList();
    final seedInfos =
        _references.where((r) => r.type == CropReferenceType.seedInfo).toList();
    final webRefs =
        _references.where((r) => r.type == CropReferenceType.web).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Text(l.cultivationInfo,
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),

            // Seed packet photos
            if (seedPhotos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l.seedPacketPhotos,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 4),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: seedPhotos.length,
                  itemBuilder: (context, index) {
                    final ref = seedPhotos[index];
                    final file = File(ref.filePath!);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showPhotoFullScreen(
                          RecordPhoto(recordId: '', filePath: ref.filePath!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: file.existsSync()
                              ? Image.file(file,
                                  height: 100, width: 100, fit: BoxFit.cover)
                              : Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // AI-extracted cultivation info
            if (seedInfos.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...seedInfos.map((ref) {
                CultivationData? data;
                try {
                  data = CultivationData.fromJson(jsonDecode(ref.content));
                } catch (_) {}
                if (data == null) {
                  return Text(ref.content);
                }
                final fields = data.displayFields;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ref.title.isNotEmpty)
                      Text(ref.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ...fields.map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(field.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    )),
                              ),
                              Expanded(
                                child: Text(field.value,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        )),
                    if (ref.url != null) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _openUrl(ref.url!),
                        child: Text(
                          ref.url!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],

            // Web references
            if (webRefs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l.cultivationReferences,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 4),
              ...webRefs.map((ref) => InkWell(
                    onTap: ref.url != null ? () => _openUrl(ref.url!) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.link,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ref.title.isNotEmpty ? ref.title : (ref.url ?? ''),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _RecordWithPhotos {
  final GrowRecord record;
  final List<RecordPhoto> photos;

  _RecordWithPhotos({required this.record, required this.photos});
}
