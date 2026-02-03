import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../services/database_service.dart';

class LocationsScreen extends StatefulWidget {
  final DatabaseService db;

  const LocationsScreen({super.key, required this.db});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
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

  Future<void> _showLocationForm({Location? existing}) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? l.addLocation : l.editLocation),
        content: Column(
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
              decoration: InputDecoration(labelText: l.locationDescription),
            ),
          ],
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
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    final location = Location(
      id: existing?.id,
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
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

  void _openPlots(Location location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlotsScreen(db: widget.db, location: location),
      ),
    );
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
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(loc.name),
                        subtitle: loc.description.isNotEmpty
                            ? Text(loc.description)
                            : null,
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

  Future<void> _showForm({Plot? existing}) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? l.addPlot : l.editPlot),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l.plotName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memoCtrl,
              decoration: InputDecoration(labelText: l.memo),
              maxLines: 3,
            ),
          ],
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
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    final plot = Plot(
      id: existing?.id,
      locationId: widget.location.id,
      name: nameCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.location.name} - ${l.plots}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plots.isEmpty
              ? Center(child: Text(l.noPlots))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plots.length,
                  itemBuilder: (context, index) {
                    final plot = _plots[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.grid_view),
                        title: Text(plot.name),
                        subtitle: plot.memo.isNotEmpty
                            ? Text(plot.memo)
                            : null,
                        onTap: () => _showForm(existing: plot),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(plot),
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
