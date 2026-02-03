import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/record.dart';
import '../models/record_photo.dart';
import '../services/database_service.dart';
import '../services/photo_service.dart';

class RecordsScreen extends StatefulWidget {
  final DatabaseService db;

  const RecordsScreen({super.key, required this.db});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _photoService = PhotoService();
  final _picker = ImagePicker();
  List<GrowRecord> _records = [];
  List<Crop> _crops = [];
  Map<String, List<RecordPhoto>> _photosByRecord = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final crops = await widget.db.getCrops();
    final records = await widget.db.getRecords();
    final photosByRecord = <String, List<RecordPhoto>>{};
    for (final rec in records) {
      photosByRecord[rec.id] = await widget.db.getPhotos(rec.id);
    }
    if (!mounted) return;
    setState(() {
      _crops = crops;
      _records = records;
      _photosByRecord = photosByRecord;
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

  String _cropName(String cropId) {
    final crop = _crops.where((c) => c.id == cropId).firstOrNull;
    return crop?.name ?? '';
  }

  Future<void> _showForm({GrowRecord? existing}) async {
    final l = AppLocalizations.of(context)!;

    if (_crops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noCrops)),
      );
      return;
    }

    var selectedCropId = existing?.cropId ?? _crops.first.id;
    var selectedActivity = existing?.activityType ?? ActivityType.observation;
    var selectedDate = existing?.date ?? DateTime.now();
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    // Load existing photos
    List<RecordPhoto> existingPhotos = [];
    if (existing != null) {
      existingPhotos = List.of(await widget.db.getPhotos(existing.id));
    }
    // Newly picked file paths (not yet saved)
    List<String> newPhotoPaths = [];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? l.addRecord : l.editRecord),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo area at top
                _buildPhotoArea(
                  ctx, l, existingPhotos, newPhotoPaths, setDialogState,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCropId,
                  decoration: InputDecoration(labelText: l.crops),
                  items: _crops
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCropId = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ActivityType>(
                  value: selectedActivity,
                  decoration: InputDecoration(labelText: l.activityType),
                  items: ActivityType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_activityLabel(l, t)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedActivity = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.date),
                  subtitle: Text(
                    '${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
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
      id: existing?.id,
      cropId: selectedCropId,
      activityType: selectedActivity,
      date: selectedDate,
      note: noteCtrl.text.trim(),
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertRecord(record);
    } else {
      await widget.db.updateRecord(record);
    }

    // Save new photos
    for (var i = 0; i < newPhotoPaths.length; i++) {
      final savedPath = await _photoService.savePhoto(newPhotoPaths[i]);
      final photo = RecordPhoto(
        recordId: record.id,
        filePath: savedPath,
        sortOrder: existingPhotos.length + i,
      );
      await widget.db.insertPhoto(photo);
    }

    _load();
  }

  Widget _buildPhotoArea(
    BuildContext ctx,
    AppLocalizations l,
    List<RecordPhoto> existingPhotos,
    List<String> newPhotoPaths,
    StateSetter setDialogState,
  ) {
    final items = <Widget>[
      // Existing photos
      ...existingPhotos.map((photo) => _photoThumbnail(
            image: Image.file(
              File(photo.filePath),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
            onRemove: () async {
              await _photoService.deletePhotoFile(photo.filePath);
              await widget.db.deletePhoto(photo.id);
              setDialogState(() => existingPhotos.remove(photo));
            },
          )),
      // New photos (not yet saved)
      ...newPhotoPaths.asMap().entries.map((entry) => _photoThumbnail(
            image: Image.file(
              File(entry.value),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
            onRemove: () {
              setDialogState(() => newPhotoPaths.removeAt(entry.key));
            },
          )),
      // Add button
      GestureDetector(
        onTap: () => _showPhotoOptions(ctx, l, newPhotoPaths, setDialogState),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(ctx).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.add_a_photo,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];

    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items
            .map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w))
            .toList(),
      ),
    );
  }

  Widget _photoThumbnail({required Image image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: image,
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showPhotoOptions(
    BuildContext ctx,
    AppLocalizations l,
    List<String> newPhotoPaths,
    StateSetter setDialogState,
  ) {
    showModalBottomSheet(
      context: ctx,
      builder: (bsCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l.takePhoto),
              onTap: () async {
                Navigator.pop(bsCtx);
                final xFile =
                    await _picker.pickImage(source: ImageSource.camera);
                if (xFile != null) {
                  setDialogState(() => newPhotoPaths.add(xFile.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l.pickFromGallery),
              onTap: () async {
                Navigator.pop(bsCtx);
                final xFile =
                    await _picker.pickImage(source: ImageSource.gallery);
                if (xFile != null) {
                  setDialogState(() => newPhotoPaths.add(xFile.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(GrowRecord record) async {
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

    // Delete associated photos
    final photos = await widget.db.getPhotos(record.id);
    for (final photo in photos) {
      await _photoService.deletePhotoFile(photo.filePath);
      await widget.db.deletePhoto(photo.id);
    }

    await widget.db.deleteRecord(record.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.records)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(child: Text(l.noRecords))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final rec = _records[index];
                    final photos = _photosByRecord[rec.id] ?? [];
                    final dateStr =
                        '${rec.date.year}/${rec.date.month.toString().padLeft(2, '0')}/${rec.date.day.toString().padLeft(2, '0')}';
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showForm(existing: rec),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Photo thumbnails
                            if (photos.isNotEmpty)
                              SizedBox(
                                height: 180,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: photos.length,
                                  itemBuilder: (ctx, i) => Image.file(
                                    File(photos[i].filePath),
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ListTile(
                              title: Text(
                                '${_cropName(rec.cropId)} - ${_activityLabel(l, rec.activityType)}',
                              ),
                              subtitle: Text(
                                [dateStr, if (rec.note.isNotEmpty) rec.note]
                                    .join('\n'),
                              ),
                              isThreeLine: rec.note.isNotEmpty,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(rec),
                              ),
                            ),
                          ],
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
