import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/crop.dart';
import '../models/record.dart';
import '../services/database_service.dart';

class RecordsScreen extends StatefulWidget {
  final DatabaseService db;

  const RecordsScreen({super.key, required this.db});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<GrowRecord> _records = [];
  List<Crop> _crops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final crops = await widget.db.getCrops();
    final records = await widget.db.getRecords();
    if (!mounted) return;
    setState(() {
      _crops = crops;
      _records = records;
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? l.addRecord : l.editRecord),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
    _load();
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
                    final dateStr =
                        '${rec.date.year}/${rec.date.month.toString().padLeft(2, '0')}/${rec.date.day.toString().padLeft(2, '0')}';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.edit_note),
                        title: Text(
                          '${_cropName(rec.cropId)} - ${_activityLabel(l, rec.activityType)}',
                        ),
                        subtitle: Text(
                          [dateStr, if (rec.note.isNotEmpty) rec.note]
                              .join('\n'),
                        ),
                        isThreeLine: rec.note.isNotEmpty,
                        onTap: () => _showForm(existing: rec),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(rec),
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
