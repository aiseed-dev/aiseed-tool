import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../models/record.dart';
import '../models/record_photo.dart';
import '../services/database_service.dart';
import '../services/image_analysis_service.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../services/plant_identification_service.dart';
import 'settings_screen.dart';

enum _LinkType { location, plot, crop }

class RecordsScreen extends StatefulWidget {
  final DatabaseService db;

  const RecordsScreen({super.key, required this.db});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _photoService = PhotoService();
  final _locationService = LocationService();
  final _imageAnalysis = ImageAnalysisService();
  final _picker = ImagePicker();
  List<GrowRecord> _records = [];
  List<Crop> _crops = [];
  List<Location> _locations = [];
  List<Plot> _allPlots = [];
  Map<String, List<RecordPhoto>> _photosByRecord = {};
  bool _loading = true;

  // Search & filter state
  bool _isSearching = false;
  String _searchQuery = '';
  ActivityType? _filterActivity;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _imageAnalysis.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final crops = await widget.db.getCrops();
    final locations = await widget.db.getLocations();
    final allPlots = await widget.db.getAllPlots();
    final records = await widget.db.getRecords();
    final photosByRecord = <String, List<RecordPhoto>>{};
    for (final rec in records) {
      photosByRecord[rec.id] = await widget.db.getPhotos(rec.id);
    }
    if (!mounted) return;
    setState(() {
      _crops = crops;
      _locations = locations;
      _allPlots = allPlots;
      _records = records;
      _photosByRecord = photosByRecord;
      _loading = false;
    });
  }

  List<GrowRecord> get _filteredRecords {
    var results = _records;

    // Filter by activity type
    if (_filterActivity != null) {
      results = results.where((r) => r.activityType == _filterActivity).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((rec) {
        // Search in note
        if (rec.note.toLowerCase().contains(query)) return true;
        // Search in linked name
        final linkName = _linkDisplayNameRaw(rec);
        if (linkName.toLowerCase().contains(query)) return true;
        return false;
      }).toList();
    }

    return results;
  }

  String _linkDisplayNameRaw(GrowRecord rec) {
    if (rec.cropId != null) {
      final crop = _crops.where((c) => c.id == rec.cropId).firstOrNull;
      if (crop != null) {
        return [crop.cultivationName, crop.name, crop.variety]
            .where((s) => s.isNotEmpty)
            .join(' ');
      }
      return '';
    }
    if (rec.plotId != null) {
      final plot = _allPlots.where((p) => p.id == rec.plotId).firstOrNull;
      if (plot != null) {
        final loc =
            _locations.where((lo) => lo.id == plot.locationId).firstOrNull;
        return loc != null ? '${loc.name} ${plot.name}' : plot.name;
      }
      return '';
    }
    if (rec.locationId != null) {
      final loc =
          _locations.where((lo) => lo.id == rec.locationId).firstOrNull;
      return loc?.name ?? '';
    }
    return '';
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

  String _linkDisplayName(GrowRecord rec, AppLocalizations l) {
    if (rec.cropId != null) {
      final crop = _crops.where((c) => c.id == rec.cropId).firstOrNull;
      return crop?.cultivationName ?? '';
    }
    if (rec.plotId != null) {
      final plot = _allPlots.where((p) => p.id == rec.plotId).firstOrNull;
      if (plot != null) {
        final loc =
            _locations.where((lo) => lo.id == plot.locationId).firstOrNull;
        return loc != null ? '${loc.name} / ${plot.name}' : plot.name;
      }
      return '';
    }
    if (rec.locationId != null) {
      final loc =
          _locations.where((lo) => lo.id == rec.locationId).firstOrNull;
      return loc?.name ?? '';
    }
    return '';
  }

  _LinkType _detectLinkType(GrowRecord? rec) {
    if (rec?.plotId != null) return _LinkType.plot;
    if (rec?.locationId != null) return _LinkType.location;
    return _LinkType.crop;
  }

  /// 写真を分析して、リンク先を自動提案する
  Future<void> _analyzeAndSuggest({
    required String imagePath,
    required StateSetter setDialogState,
    required ValueNotifier<_LinkType> linkType,
    required ValueNotifier<String?> selectedCropId,
    required ValueNotifier<String?> selectedLocationId,
    required ValueNotifier<String?> selectedPlotId,
    required ValueNotifier<String> analysisStatus,
  }) async {
    final l = AppLocalizations.of(context)!;

    // Stage 1: ML Kit on-device classification
    analysisStatus.value = l.analyzing;
    setDialogState(() {});

    final result = await _imageAnalysis.analyze(imagePath);

    if (result.hasPlant) {
      analysisStatus.value = l.plantDetected;
      setDialogState(() {});

      // Stage 2: Cloud API for crop identification (if provider configured)
      final prefs = await SharedPreferences.getInstance();
      final providerIndex = prefs.getInt(kPlantIdProviderPref) ?? 0;
      final provider = PlantIdProvider.values[
          providerIndex.clamp(0, PlantIdProvider.values.length - 1)];
      final plantIdService = PlantIdentificationService.create(
        provider: provider,
        plantIdApiKey: prefs.getString(kPlantIdApiKeyPref),
        serverUrl: prefs.getString(kServerUrlPref),
        serverToken: prefs.getString(kServerTokenPref),
      );

      if (plantIdService.isAvailable) {
        analysisStatus.value = l.identifyingPlant;
        setDialogState(() {});

        final identifications = await plantIdService.identify(imagePath);

        if (identifications.isNotEmpty) {
          final bestMatch = identifications.first;
          final desc = bestMatch.description;
          analysisStatus.value = desc != null && desc.isNotEmpty
              ? '${l.plantIdentified(bestMatch.name)}\n$desc'
              : l.plantIdentified(bestMatch.name);
          setDialogState(() {});

          // Stage 3: Auto-suggest link based on crop name match
          final matchedCrop = _findCropByName(bestMatch.name);
          if (matchedCrop != null) {
            linkType.value = _LinkType.crop;
            selectedCropId.value = matchedCrop.id;
            selectedLocationId.value = null;
            selectedPlotId.value = null;
            analysisStatus.value =
                l.suggestedLink(matchedCrop.cultivationName);
            setDialogState(() {});
            return;
          }
        }
      }

      // Plant detected but no crop match - suggest crop link type
      if (_crops.isNotEmpty && linkType.value != _LinkType.crop) {
        linkType.value = _LinkType.crop;
        selectedCropId.value = _crops.first.id;
        selectedLocationId.value = null;
        selectedPlotId.value = null;
        setDialogState(() {});
      }
    } else if (result.isLandscape) {
      analysisStatus.value = l.landscapeDetected;
      setDialogState(() {});

      // Landscape → suggest location or plot link
      if (_allPlots.isNotEmpty && linkType.value == _LinkType.crop) {
        linkType.value = _LinkType.plot;
        selectedCropId.value = null;
        selectedPlotId.value = _allPlots.first.id;
        selectedLocationId.value = null;
        setDialogState(() {});
      } else if (_locations.isNotEmpty && linkType.value == _LinkType.crop) {
        linkType.value = _LinkType.location;
        selectedCropId.value = null;
        selectedPlotId.value = null;
        selectedLocationId.value = _locations.first.id;
        setDialogState(() {});
      }
    } else {
      analysisStatus.value = l.noPlantDetected;
      setDialogState(() {});
    }
  }

  /// 作物名でCropを検索（部分一致）
  Crop? _findCropByName(String plantName) {
    final lower = plantName.toLowerCase();
    for (final crop in _crops) {
      final cropNameLower = crop.name.toLowerCase();
      final cultivationLower = crop.cultivationName.toLowerCase();
      if (cropNameLower.isNotEmpty && lower.contains(cropNameLower)) {
        return crop;
      }
      if (cultivationLower.isNotEmpty && lower.contains(cultivationLower)) {
        return crop;
      }
      if (cropNameLower.isNotEmpty && cropNameLower.contains(lower)) {
        return crop;
      }
    }
    return null;
  }

  Future<void> _showForm({GrowRecord? existing}) async {
    final l = AppLocalizations.of(context)!;

    final linkType = ValueNotifier(_detectLinkType(existing));
    final selectedCropId = ValueNotifier<String?>(existing?.cropId);
    final selectedLocationId = ValueNotifier<String?>(existing?.locationId);
    final selectedPlotId = ValueNotifier<String?>(existing?.plotId);
    final analysisStatus = ValueNotifier<String>('');

    // Set defaults for new records - try GPS auto-detect first
    if (existing == null) {
      final pos = await _locationService.getCurrentPosition();
      Location? nearestLoc;
      if (pos != null) {
        nearestLoc = _locationService.findNearest(
          _locations, pos.latitude, pos.longitude,
        );
      }

      if (nearestLoc != null) {
        final plotsAtLoc = _allPlots
            .where((p) => p.locationId == nearestLoc!.id)
            .toList();
        final cropAtLoc = plotsAtLoc.isNotEmpty
            ? _crops
                .where((c) => plotsAtLoc.any((p) => p.id == c.plotId))
                .firstOrNull
            : null;

        if (cropAtLoc != null) {
          linkType.value = _LinkType.crop;
          selectedCropId.value = cropAtLoc.id;
        } else if (plotsAtLoc.isNotEmpty) {
          linkType.value = _LinkType.plot;
          selectedPlotId.value = plotsAtLoc.first.id;
        } else {
          linkType.value = _LinkType.location;
          selectedLocationId.value = nearestLoc.id;
        }
      } else {
        if (_crops.isNotEmpty) {
          linkType.value = _LinkType.crop;
          selectedCropId.value = _crops.first.id;
        } else if (_allPlots.isNotEmpty) {
          linkType.value = _LinkType.plot;
          selectedPlotId.value = _allPlots.first.id;
        } else if (_locations.isNotEmpty) {
          linkType.value = _LinkType.location;
          selectedLocationId.value = _locations.first.id;
        }
      }
    }

    var selectedActivity = existing?.activityType ?? ActivityType.observation;
    var selectedDate = existing?.date ?? DateTime.now();
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    List<RecordPhoto> existingPhotos = [];
    if (existing != null) {
      existingPhotos = List.of(await widget.db.getPhotos(existing.id));
    }
    List<String> newPhotoPaths = [];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? l.addRecord : l.editRecord,
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  // Photo area
                  _buildPhotoArea(
                    ctx, l, existingPhotos, newPhotoPaths, setDialogState,
                    linkType: linkType,
                    selectedCropId: selectedCropId,
                    selectedLocationId: selectedLocationId,
                    selectedPlotId: selectedPlotId,
                    analysisStatus: analysisStatus,
                    onDateDetected: (date) => selectedDate = date,
                  ),
                  // Analysis status chip
                  ValueListenableBuilder<String>(
                    valueListenable: analysisStatus,
                    builder: (_, status, __) {
                      if (status.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Chip(
                          avatar: const Icon(Icons.auto_awesome, size: 16),
                          label: Text(
                            status,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Link type selector
                  ValueListenableBuilder<_LinkType>(
                    valueListenable: linkType,
                    builder: (_, currentLinkType, __) =>
                        DropdownButtonFormField<_LinkType>(
                      initialValue: currentLinkType,
                      decoration: InputDecoration(labelText: l.linkTarget),
                      items: [
                        if (_locations.isNotEmpty)
                          DropdownMenuItem(
                            value: _LinkType.location,
                            child: Text(l.linkToLocation),
                          ),
                        if (_allPlots.isNotEmpty)
                          DropdownMenuItem(
                            value: _LinkType.plot,
                            child: Text(l.linkToPlot),
                          ),
                        if (_crops.isNotEmpty)
                          DropdownMenuItem(
                            value: _LinkType.crop,
                            child: Text(l.linkToCrop),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          linkType.value = v;
                          selectedCropId.value =
                              v == _LinkType.crop && _crops.isNotEmpty
                                  ? _crops.first.id
                                  : null;
                          selectedLocationId.value =
                              v == _LinkType.location && _locations.isNotEmpty
                                  ? _locations.first.id
                                  : null;
                          selectedPlotId.value =
                              v == _LinkType.plot && _allPlots.isNotEmpty
                                  ? _allPlots.first.id
                                  : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Link target selector based on type
                  ValueListenableBuilder<_LinkType>(
                    valueListenable: linkType,
                    builder: (_, currentLinkType, __) {
                      if (currentLinkType == _LinkType.crop &&
                          _crops.isNotEmpty) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: selectedCropId,
                          builder: (_, cropId, __) =>
                              DropdownButtonFormField<String>(
                            key: ValueKey('crop_$cropId'),
                            initialValue: cropId ?? _crops.first.id,
                            decoration:
                                InputDecoration(labelText: l.crops),
                            items: _crops
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.cultivationName),
                                    ))
                                .toList(),
                            onChanged: (v) => selectedCropId.value = v,
                          ),
                        );
                      }
                      if (currentLinkType == _LinkType.location &&
                          _locations.isNotEmpty) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: selectedLocationId,
                          builder: (_, locId, __) =>
                              DropdownButtonFormField<String>(
                            key: ValueKey('loc_$locId'),
                            initialValue: locId ?? _locations.first.id,
                            decoration:
                                InputDecoration(labelText: l.locations),
                            items: _locations
                                .map((loc) => DropdownMenuItem(
                                      value: loc.id,
                                      child: Text(loc.name),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                selectedLocationId.value = v,
                          ),
                        );
                      }
                      if (currentLinkType == _LinkType.plot &&
                          _allPlots.isNotEmpty) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: selectedPlotId,
                          builder: (_, plotId, __) =>
                              DropdownButtonFormField<String>(
                            key: ValueKey('plot_$plotId'),
                            initialValue: plotId ?? _allPlots.first.id,
                            decoration:
                                InputDecoration(labelText: l.plots),
                            items: _allPlots.map((plot) {
                              final loc = _locations
                                  .where(
                                      (lo) => lo.id == plot.locationId)
                                  .firstOrNull;
                              final label = loc != null
                                  ? '${loc.name} / ${plot.name}'
                                  : plot.name;
                              return DropdownMenuItem(
                                value: plot.id,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                selectedPlotId.value = v,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ActivityType>(
                    initialValue: selectedActivity,
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
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved != true) return;

    final record = GrowRecord(
      id: existing?.id,
      cropId: linkType.value == _LinkType.crop ? selectedCropId.value : null,
      locationId:
          linkType.value == _LinkType.location ? selectedLocationId.value : null,
      plotId: linkType.value == _LinkType.plot ? selectedPlotId.value : null,
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
    StateSetter setDialogState, {
    required ValueNotifier<_LinkType> linkType,
    required ValueNotifier<String?> selectedCropId,
    required ValueNotifier<String?> selectedLocationId,
    required ValueNotifier<String?> selectedPlotId,
    required ValueNotifier<String> analysisStatus,
    required void Function(DateTime) onDateDetected,
  }) {
    final items = <Widget>[
      ...existingPhotos.map((photo) => _photoThumbnail(
            image: Image.file(
              File(photo.filePath),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image),
              ),
            ),
            onRemove: () async {
              await _photoService.deletePhotoFile(photo.filePath);
              await widget.db.deletePhoto(photo.id);
              setDialogState(() => existingPhotos.remove(photo));
            },
          )),
      ...newPhotoPaths.asMap().entries.map((entry) => _photoThumbnail(
            image: Image.file(
              File(entry.value),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image),
              ),
            ),
            onRemove: () {
              setDialogState(() => newPhotoPaths.removeAt(entry.key));
            },
          )),
      GestureDetector(
        onTap: () => _showPhotoOptions(
          ctx, l, newPhotoPaths, setDialogState,
          linkType: linkType,
          selectedCropId: selectedCropId,
          selectedLocationId: selectedLocationId,
          selectedPlotId: selectedPlotId,
          analysisStatus: analysisStatus,
          onDateDetected: onDateDetected,
        ),
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }

  Widget _photoThumbnail(
      {required Image image, required VoidCallback onRemove}) {
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

  Future<void> _pickAndAnalyze({
    required ImageSource source,
    required List<String> newPhotoPaths,
    required StateSetter setDialogState,
    required ValueNotifier<_LinkType> linkType,
    required ValueNotifier<String?> selectedCropId,
    required ValueNotifier<String?> selectedLocationId,
    required ValueNotifier<String?> selectedPlotId,
    required ValueNotifier<String> analysisStatus,
    required void Function(DateTime) onDateDetected,
  }) async {
    // Gallery: allow multi-select; Camera: single
    if (source == ImageSource.gallery) {
      final xFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (xFiles.isEmpty) return;
      setDialogState(() {
        for (final f in xFiles) {
          newPhotoPaths.add(f.path);
        }
      });
      // Set record date from first photo's file date
      try {
        final firstFile = File(xFiles.first.path);
        final lastModified = await firstFile.lastModified();
        setDialogState(() => onDateDetected(lastModified));
      } catch (_) {}
      // Analyze only the first selected photo for auto-link suggestion
      _analyzeAndSuggest(
        imagePath: xFiles.first.path,
        setDialogState: setDialogState,
        linkType: linkType,
        selectedCropId: selectedCropId,
        selectedLocationId: selectedLocationId,
        selectedPlotId: selectedPlotId,
        analysisStatus: analysisStatus,
      );
    } else {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (xFile == null) return;
      setDialogState(() => newPhotoPaths.add(xFile.path));
      _analyzeAndSuggest(
        imagePath: xFile.path,
        setDialogState: setDialogState,
        linkType: linkType,
        selectedCropId: selectedCropId,
        selectedLocationId: selectedLocationId,
        selectedPlotId: selectedPlotId,
        analysisStatus: analysisStatus,
      );
    }
  }

  void _showPhotoOptions(
    BuildContext ctx,
    AppLocalizations l,
    List<String> newPhotoPaths,
    StateSetter setDialogState, {
    required ValueNotifier<_LinkType> linkType,
    required ValueNotifier<String?> selectedCropId,
    required ValueNotifier<String?> selectedLocationId,
    required ValueNotifier<String?> selectedPlotId,
    required ValueNotifier<String> analysisStatus,
    required void Function(DateTime) onDateDetected,
  }) {
    showModalBottomSheet(
      context: ctx,
      builder: (bsCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l.takePhoto),
              onTap: () {
                Navigator.pop(bsCtx);
                _pickAndAnalyze(
                  source: ImageSource.camera,
                  newPhotoPaths: newPhotoPaths,
                  setDialogState: setDialogState,
                  linkType: linkType,
                  selectedCropId: selectedCropId,
                  selectedLocationId: selectedLocationId,
                  selectedPlotId: selectedPlotId,
                  analysisStatus: analysisStatus,
                  onDateDetected: onDateDetected,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l.pickFromGallery),
              onTap: () {
                Navigator.pop(bsCtx);
                _pickAndAnalyze(
                  source: ImageSource.gallery,
                  newPhotoPaths: newPhotoPaths,
                  setDialogState: setDialogState,
                  linkType: linkType,
                  selectedCropId: selectedCropId,
                  selectedLocationId: selectedLocationId,
                  selectedPlotId: selectedPlotId,
                  analysisStatus: analysisStatus,
                  onDateDetected: onDateDetected,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordMenu(GrowRecord record) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.editRecord),
              onTap: () {
                Navigator.pop(ctx);
                _showForm(existing: record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
              onTap: () {
                Navigator.pop(ctx);
                _delete(record);
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
    final filtered = _filteredRecords;

    return Scaffold(
      appBar: _isSearching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              actions: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            )
          : AppBar(
              title: Text(l.records),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l.searchRecords,
                  onPressed: () => setState(() => _isSearching = true),
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Activity filter chips
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(l.allActivities),
                          selected: _filterActivity == null,
                          onSelected: (_) =>
                              setState(() => _filterActivity = null),
                        ),
                      ),
                      ...ActivityType.values.map((type) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(_activityLabel(l, type)),
                              selected: _filterActivity == type,
                              onSelected: (_) => setState(() =>
                                  _filterActivity =
                                      _filterActivity == type ? null : type),
                            ),
                          )),
                    ],
                  ),
                ),
                // Records list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text(l.noRecords))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final rec = filtered[index];
                            final photos = _photosByRecord[rec.id] ?? [];
                            final dateStr =
                                '${rec.date.year}/${rec.date.month.toString().padLeft(2, '0')}/${rec.date.day.toString().padLeft(2, '0')}';
                            final linkName = _linkDisplayName(rec, l);
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _showForm(existing: rec),
                                onLongPress: () => _showRecordMenu(rec),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 180,
                                              height: 180,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 48,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ListTile(
                                      title: Text(
                                        [
                                          if (linkName.isNotEmpty) linkName,
                                          _activityLabel(l, rec.activityType),
                                        ].join(' - '),
                                      ),
                                      subtitle: Text(
                                        [
                                          dateStr,
                                          if (rec.note.isNotEmpty) rec.note,
                                        ].join('\n'),
                                      ),
                                      isThreeLine: rec.note.isNotEmpty,
                                    ),
                                  ],
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
