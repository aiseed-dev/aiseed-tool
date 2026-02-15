import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../models/record.dart';
import '../models/record_photo.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'crop_detail_screen.dart';

class LocationsScreen extends StatefulWidget {
  final DatabaseService db;

  const LocationsScreen({super.key, required this.db});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _locationService = LocationService();
  List<Location> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locations = await widget.db.getLocations();
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _loading = false;
    });
  }

  String _envLabel(AppLocalizations l, EnvironmentType type) {
    switch (type) {
      case EnvironmentType.outdoor:
        return l.envOutdoor;
      case EnvironmentType.indoor:
        return l.envIndoor;
      case EnvironmentType.balcony:
        return l.envBalcony;
      case EnvironmentType.rooftop:
        return l.envRooftop;
    }
  }

  Future<void> _showLocationForm({Location? existing}) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var selectedEnvType = existing?.environmentType ?? EnvironmentType.outdoor;
    double? lat = existing?.latitude;
    double? lng = existing?.longitude;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? l.addLocation : l.editLocation),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l.locationName),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration:
                      InputDecoration(labelText: l.locationDescription),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EnvironmentType>(
                  initialValue: selectedEnvType,
                  decoration:
                      InputDecoration(labelText: l.environmentType),
                  items: EnvironmentType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_envLabel(l, t)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedEnvType = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lat != null && lng != null
                            ? '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                            : '---',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.my_location, size: 18),
                      label: Text(l.getLocation),
                      onPressed: () async {
                        final pos =
                            await _locationService.getCurrentPosition();
                        if (pos != null) {
                          setDialogState(() {
                            lat = pos.latitude;
                            lng = pos.longitude;
                          });
                        } else if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l.locationFailed)),
                          );
                        }
                      },
                    ),
                  ],
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

    final location = Location(
      id: existing?.id,
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
      environmentType: selectedEnvType,
      latitude: lat,
      longitude: lng,
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertLocation(location);
    } else {
      await widget.db.updateLocation(location);
    }
    _load();
  }

  Future<void> _deleteLocation(Location location) async {
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
    await widget.db.deleteLocation(location.id);
    _load();
  }

  void _showLocationMenu(Location location) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.editLocation),
              onTap: () {
                Navigator.pop(ctx);
                _showLocationForm(existing: location);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
              onTap: () {
                Navigator.pop(ctx);
                _deleteLocation(location);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlots(Location location) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _PlotsScreen(db: widget.db, location: location),
      ),
    );
    if (result == 'edit') {
      await _showLocationForm(existing: location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.locations)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? Center(child: Text(l.noLocations))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final loc = _locations[index];
                    final envLabel = _envLabel(l, loc.environmentType);
                    final subtitle = [
                      envLabel,
                      if (loc.latitude != null && loc.longitude != null)
                        '${loc.latitude!.toStringAsFixed(4)}, ${loc.longitude!.toStringAsFixed(4)}',
                      if (loc.description.isNotEmpty) loc.description,
                    ].join(' / ');
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(loc.name),
                        subtitle: Text(subtitle),
                        onTap: () => _openPlots(loc),
                        onLongPress: () => _showLocationMenu(loc),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLocationForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// -- Plots Screen (navigated from location tap) --

class _PlotsScreen extends StatefulWidget {
  final DatabaseService db;
  final Location location;

  const _PlotsScreen({required this.db, required this.location});

  @override
  State<_PlotsScreen> createState() => _PlotsScreenState();
}

class _PlotsScreenState extends State<_PlotsScreen> {
  List<Plot> _plots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plots = await widget.db.getPlots(widget.location.id);
    if (!mounted) return;
    setState(() {
      _plots = plots;
      _loading = false;
    });
  }

  String _coverLabel(AppLocalizations l, CoverType type) {
    switch (type) {
      case CoverType.open:
        return l.coverOpen;
      case CoverType.greenhouse:
        return l.coverGreenhouse;
      case CoverType.tunnel:
        return l.coverTunnel;
      case CoverType.coldFrame:
        return l.coverColdFrame;
    }
  }

  String _soilLabel(AppLocalizations l, SoilType type) {
    switch (type) {
      case SoilType.unknown:
        return l.soilUnknown;
      case SoilType.clay:
        return l.soilCite;
      case SoilType.silt:
        return l.soilSilt;
      case SoilType.sandy:
        return l.soilSandy;
      case SoilType.loam:
        return l.soilLoam;
      case SoilType.peat:
        return l.soilPeat;
      case SoilType.volcanic:
        return l.soilVolcanic;
    }
  }

  Future<void> _showForm({Plot? existing}) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    var selectedCover = existing?.coverType ?? CoverType.open;
    var selectedSoil = existing?.soilType ?? SoilType.unknown;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? l.addPlot : l.editPlot),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l.plotName),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CoverType>(
                  initialValue: selectedCover,
                  decoration: InputDecoration(labelText: l.coverType),
                  items: CoverType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_coverLabel(l, t)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCover = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SoilType>(
                  initialValue: selectedSoil,
                  decoration: InputDecoration(labelText: l.soilType),
                  items: SoilType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_soilLabel(l, t)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedSoil = v!),
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
        ),
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    final plot = Plot(
      id: existing?.id,
      locationId: widget.location.id,
      name: nameCtrl.text.trim(),
      coverType: selectedCover,
      soilType: selectedSoil,
      memo: memoCtrl.text.trim(),
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertPlot(plot);
    } else {
      await widget.db.updatePlot(plot);
    }
    _load();
  }

  Future<void> _delete(Plot plot) async {
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
    await widget.db.deletePlot(plot.id);
    _load();
  }

  String _envLabel(AppLocalizations l, EnvironmentType type) {
    switch (type) {
      case EnvironmentType.outdoor:
        return l.envOutdoor;
      case EnvironmentType.indoor:
        return l.envIndoor;
      case EnvironmentType.balcony:
        return l.envBalcony;
      case EnvironmentType.rooftop:
        return l.envRooftop;
    }
  }

  Widget _buildLocationDetail(AppLocalizations l) {
    final loc = widget.location;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    await _editLocation();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.nature, size: 16),
                const SizedBox(width: 6),
                Text(_envLabel(l, loc.environmentType)),
              ],
            ),
            if (loc.latitude != null && loc.longitude != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.gps_fixed, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${loc.latitude!.toStringAsFixed(5)}, ${loc.longitude!.toStringAsFixed(5)}',
                  ),
                ],
              ),
            ],
            if (loc.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(loc.description)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPlotMenu(Plot plot) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.editPlot),
              onTap: () {
                Navigator.pop(ctx);
                _showForm(existing: plot);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
              onTap: () {
                Navigator.pop(ctx);
                _delete(plot);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlotDetail(Plot plot) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlotDetailScreen(db: widget.db, plot: plot),
      ),
    );
    _load();
  }

  Future<void> _editLocation() async {
    // Navigate back and trigger edit on parent
    // For simplicity, we use the same pattern as LocationsScreen
    Navigator.pop(context, 'edit');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildLocationDetail(l),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        l.plots,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _plots.isEmpty
                      ? Center(child: Text(l.noPlots))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _plots.length,
                          itemBuilder: (context, index) {
                            final plot = _plots[index];
                            final details = [
                              if (plot.coverType != CoverType.open)
                                _coverLabel(l, plot.coverType),
                              if (plot.soilType != SoilType.unknown)
                                _soilLabel(l, plot.soilType),
                              if (plot.memo.isNotEmpty) plot.memo,
                            ].join(' / ');
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.grid_view),
                                title: Text(plot.name),
                                subtitle:
                                    details.isNotEmpty ? Text(details) : null,
                                onTap: () => _openPlotDetail(plot),
                                onLongPress: () => _showPlotMenu(plot),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// -- Plot Detail Screen (navigated from plot tap) --

class _PlotDetailScreen extends StatefulWidget {
  final DatabaseService db;
  final Plot plot;

  const _PlotDetailScreen({required this.db, required this.plot});

  @override
  State<_PlotDetailScreen> createState() => _PlotDetailScreenState();
}

class _PlotDetailScreenState extends State<_PlotDetailScreen> {
  List<Crop> _crops = [];
  List<_RecordWithPhotos> _timeline = [];
  bool _loading = true;
  bool _aiSoilLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final crops = await widget.db.getCropsByPlot(widget.plot.id);
    // この区画に紐づくレコード（locationId or plotId 経由）
    final plotRecords = await widget.db.getRecords(plotId: widget.plot.id);
    final locationRecords =
        await widget.db.getRecords(locationId: widget.plot.locationId);
    // 重複排除してマージ
    final allRecordMap = <String, GrowRecord>{};
    for (final r in plotRecords) {
      allRecordMap[r.id] = r;
    }
    for (final r in locationRecords) {
      allRecordMap[r.id] = r;
    }
    // 作物経由のレコードも含める（この区画の作物に紐づくレコード）
    for (final crop in crops) {
      final cropRecords = await widget.db.getRecords(cropId: crop.id);
      for (final r in cropRecords) {
        allRecordMap[r.id] = r;
      }
    }
    final allRecords = allRecordMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final timeline = <_RecordWithPhotos>[];
    for (final rec in allRecords) {
      final photos = await widget.db.getPhotos(rec.id);
      timeline.add(_RecordWithPhotos(record: rec, photos: photos));
    }
    if (!mounted) return;
    setState(() {
      _crops = crops;
      _timeline = timeline;
      _loading = false;
    });
  }

  String _coverLabel(AppLocalizations l, CoverType type) {
    switch (type) {
      case CoverType.open:
        return l.coverOpen;
      case CoverType.greenhouse:
        return l.coverGreenhouse;
      case CoverType.tunnel:
        return l.coverTunnel;
      case CoverType.coldFrame:
        return l.coverColdFrame;
    }
  }

  String _soilLabel(AppLocalizations l, SoilType type) {
    switch (type) {
      case SoilType.unknown:
        return l.soilUnknown;
      case SoilType.clay:
        return l.soilCite;
      case SoilType.silt:
        return l.soilSilt;
      case SoilType.sandy:
        return l.soilSandy;
      case SoilType.loam:
        return l.soilLoam;
      case SoilType.peat:
        return l.soilPeat;
      case SoilType.volcanic:
        return l.soilVolcanic;
    }
  }

  Widget _buildPlotDetail(AppLocalizations l) {
    final plot = widget.plot;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plot.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.roofing, size: 16),
                const SizedBox(width: 6),
                Text('${l.coverType}: ${_coverLabel(l, plot.coverType)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.terrain, size: 16),
                const SizedBox(width: 6),
                Text('${l.soilType}: ${_soilLabel(l, plot.soilType)}'),
              ],
            ),
            if (plot.memo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(plot.memo)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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

  /// AI 土壌分析
  Future<void> _showAiSoilAnalysis(AppLocalizations l) async {
    final ai = await AiService.fromPrefs();
    if (!ai.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.aiChatProvider}: ${l.aiChatApiKeyHint}')),
      );
      return;
    }

    setState(() => _aiSoilLoading = true);

    try {
      final plot = widget.plot;
      final plotInfo = [
        '区画名: ${plot.name}',
        '被覆: ${_coverLabel(l, plot.coverType)}',
        '土質: ${_soilLabel(l, plot.soilType)}',
        if (plot.memo.isNotEmpty) 'メモ: ${plot.memo}',
      ].join('\n');

      final timelineText = _timeline.map((item) {
        final rec = item.record;
        final date = _formatDate(rec.date);
        final act = _activityLabel(l, rec.activityType);
        final parts = <String>['$date $act'];
        if (rec.note.isNotEmpty) parts.add(rec.note);
        if (rec.materials.isNotEmpty) parts.add('資材: ${rec.materials}');
        return parts.join(' / ');
      }).join('\n');

      // 現在の栽培と前作を分離
      final currentCrops = _crops.where((c) => !c.isEnded).toList();
      final pastCrops = _crops.where((c) => c.isEnded).toList();
      final currentNames = currentCrops.map((c) {
        final parts = <String>[c.cultivationName];
        if (c.variety.isNotEmpty) parts.add(c.variety);
        return parts.join('（') + (c.variety.isNotEmpty ? '）' : '');
      }).join('、');
      final pastNames = pastCrops.map((c) {
        final parts = <String>[c.cultivationName];
        if (c.variety.isNotEmpty) parts.add(c.variety);
        final period = '${_formatDate(c.startDate)}'
            '${c.endDate != null ? '〜${_formatDate(c.endDate!)}' : ''}';
        return '${parts.join("（")}${c.variety.isNotEmpty ? "）" : ""} [$period]';
      }).join('、');

      final result = await ai.request(
        '以下の区画の土壌の状態を分析してください。\n\n'
        '## 区画情報\n$plotInfo\n'
        '${currentNames.isNotEmpty ? '現在の栽培: $currentNames\n' : ''}'
        '${pastNames.isNotEmpty ? '前作（過去の栽培）: $pastNames\n' : ''}\n'
        '## この区画の活動タイムライン\n'
        '${timelineText.isNotEmpty ? timelineText : '（まだ記録がありません）'}\n\n'
        '以下の観点で報告してください：\n'
        '1. 土壌の状態の推測 — 土質・被覆・作業履歴・前作から読み取れる土の力\n'
        '2. 被覆の状態と影響 — 現在の被覆が土壌・生態系に与えている影響\n'
        '3. 前作の影響 — 前作が土壌に残した影響（根の構造、養分、微生物相への寄与）\n'
        '4. 土の変化の兆候 — タイムラインから読み取れる土壌の変化\n'
        '5. 次に観察すべきポイント — 土壌の力を判断するために注目すべき点\n'
        '日本語で回答してください。',
        systemPrompt:
            'あなたは自然栽培のコワーカーです。'
            '農薬・化学肥料は使いません。'
            '土壌の状態を最も重視します。'
            '自然栽培では、慣行農業と異なり土壌をリセットしないため、前作が土壌に大きな影響を残します。'
            '前作の根が作った土壌構造、前作が育てた微生物相、前作と現作の相性を考慮してください。'
            '土の団粒構造、微生物の活性、地表の被覆、草の状態、'
            '水はけ、土の色と匂いなど、土壌の力を見る観点からアドバイスしてください。',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.terrain, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(l.aiSoilAnalysis)),
            ],
          ),
          content: SingleChildScrollView(
            child: SelectableText(result),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.close),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.aiAnalysisError}: $e')),
      );
    } finally {
      if (mounted) setState(() => _aiSoilLoading = false);
    }
  }

  Widget _buildTimeline(AppLocalizations l) {
    if (_timeline.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _timeline.take(20).map((item) {
        final rec = item.record;
        final dateStr = _formatDate(rec.date);
        final actLabel = _activityLabel(l, rec.activityType);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (rec.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(rec.note),
                ],
                if (item.photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.photos.length,
                      itemBuilder: (context, i) {
                        final file = File(item.photos[i].filePath);
                        return Padding(
                          padding: EdgeInsets.only(
                              right: i < item.photos.length - 1 ? 6 : 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: file.existsSync()
                                ? Image.file(file,
                                    width: 80, height: 80, fit: BoxFit.cover)
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image),
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
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plot.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _buildPlotDetail(l),
                // 土壌タイムライン
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.terrain, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        l.soilTimeline,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _aiSoilLoading
                            ? null
                            : () => _showAiSoilAnalysis(l),
                        icon: _aiSoilLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                            _aiSoilLoading ? l.aiSummarizing : l.aiSoilAnalysis),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _timeline.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l.noRecords,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      : _buildTimeline(l),
                ),
                // 栽培中の作物
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        l.cropsInPlot,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                if (_crops.where((c) => !c.isEnded).isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l.noCropsInPlot,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  ..._crops.where((c) => !c.isEnded).map((crop) {
                    final subtitle = [
                      if (crop.name.isNotEmpty) crop.name,
                      if (crop.variety.isNotEmpty) crop.variety,
                    ].join(' / ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.eco),
                          title: Text(crop.cultivationName),
                          subtitle:
                              subtitle.isNotEmpty ? Text(subtitle) : null,
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CropDetailScreen(
                                  db: widget.db,
                                  crop: crop,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                // 前作（過去の栽培）
                if (_crops.any((c) => c.isEnded)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          l.cropHistory,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                  ..._crops.where((c) => c.isEnded).map((crop) {
                    final subtitle = [
                      if (crop.name.isNotEmpty) crop.name,
                      if (crop.variety.isNotEmpty) crop.variety,
                      '${_formatDate(crop.startDate)}〜${crop.endDate != null ? _formatDate(crop.endDate!) : ''}',
                    ].join(' / ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.5),
                        child: ListTile(
                          leading: Icon(Icons.eco,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          title: Text(
                            crop.cultivationName,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          subtitle:
                              subtitle.isNotEmpty ? Text(subtitle) : null,
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CropDetailScreen(
                                  db: widget.db,
                                  crop: crop,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ],
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
