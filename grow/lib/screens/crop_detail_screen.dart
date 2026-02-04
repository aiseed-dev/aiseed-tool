import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
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
  List<_RecordWithPhotos> _timeline = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await widget.db.getRecords(cropId: widget.crop.id);
    final timeline = <_RecordWithPhotos>[];
    for (final rec in records) {
      final photos = await widget.db.getPhotos(rec.id);
      timeline.add(_RecordWithPhotos(record: rec, photos: photos));
    }
    if (!mounted) return;
    setState(() {
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

  Widget _buildCropInfo(AppLocalizations l) {
    final crop = widget.crop;
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
                    crop.cultivationName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (crop.name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 28),
                  Text('${l.cropName}: ${crop.name}'),
                ],
              ),
            ],
            if (crop.variety.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 28),
                  Text('${l.variety}: ${crop.variety}'),
                ],
              ),
            ],
            if (crop.memo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(crop.memo)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${l.date}: ${crop.startDate.year}/${crop.startDate.month.toString().padLeft(2, '0')}/${crop.startDate.day.toString().padLeft(2, '0')}',
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
        title: Text(widget.crop.cultivationName),
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
