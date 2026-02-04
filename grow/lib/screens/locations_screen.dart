import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

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
                        onLongPress: () => _showLocationForm(existing: loc),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteLocation(loc),
                        ),
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
                                onLongPress: () => _showForm(existing: plot),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(plot),
                                ),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final crops = await widget.db.getCropsByPlot(widget.plot.id);
    if (!mounted) return;
    setState(() {
      _crops = crops;
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plot.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPlotDetail(l),
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
                Expanded(
                  child: _crops.isEmpty
                      ? Center(child: Text(l.noCropsInPlot))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _crops.length,
                          itemBuilder: (context, index) {
                            final crop = _crops[index];
                            final subtitle = [
                              if (crop.name.isNotEmpty) crop.name,
                              if (crop.variety.isNotEmpty) crop.variety,
                            ].join(' / ');
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.eco),
                                title: Text(crop.cultivationName),
                                subtitle:
                                    subtitle.isNotEmpty ? Text(subtitle) : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
