import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/crop_reference.dart';
import '../models/location.dart';
import '../models/plot.dart';
import '../services/cultivation_info_service.dart';
import '../services/database_service.dart';
import '../services/photo_service.dart';

class CropCreateScreen extends StatefulWidget {
  final DatabaseService db;

  const CropCreateScreen({super.key, required this.db});

  @override
  State<CropCreateScreen> createState() => _CropCreateScreenState();
}

class _CropCreateScreenState extends State<CropCreateScreen> {
  final _cultivationInfoService = CultivationInfoService();
  final _photoService = PhotoService();
  final _picker = ImagePicker();

  final _cultivationNameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _varietyCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  String? _selectedPlotId;
  String? _selectedParentCropId;
  List<Plot> _allPlots = [];
  List<Location> _locations = [];
  List<Crop> _allCrops = [];

  // Seed packet photos (local)
  final List<String> _seedPhotoPaths = [];

  // AI-extracted cultivation info
  CultivationData? _cultivationData;
  String? _cultivationDataSourceUrl;

  // Web references
  final List<_WebRef> _webRefs = [];

  bool _serverAvailable = false;
  bool _loading = true;
  bool _saving = false;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cultivationNameCtrl.dispose();
    _nameCtrl.dispose();
    _varietyCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final allPlots = await widget.db.getAllPlots();
    final locations = await widget.db.getLocations();
    final allCrops = await widget.db.getCrops();
    final serverAvailable = await _cultivationInfoService.isAvailable;
    if (!mounted) return;
    setState(() {
      _allPlots = allPlots;
      _locations = locations;
      _allCrops = allCrops;
      _serverAvailable = serverAvailable;
      _loading = false;
    });
  }

  // -- URL reading --

  Future<void> _readFromUrl() async {
    final l = AppLocalizations.of(context)!;

    if (!_serverAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.serverRequired)),
      );
      return;
    }

    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.readFromUrl),
        content: TextField(
          controller: urlCtrl,
          decoration: InputDecoration(
            labelText: l.referenceUrl,
            hintText: 'https://',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    setState(() => _reading = true);
    try {
      final data = await _cultivationInfoService.readFromUrl(url);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _cultivationData = data;
          _cultivationDataSourceUrl = url;
        });
        _offerAutoFill(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data.cached
                ? '${l.readSuccess} ${l.cachedInfo}'
                : l.readSuccess),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.readFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.readFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  // -- Seed photo AI reading --

  Future<void> _readFromSeedPhoto() async {
    final l = AppLocalizations.of(context)!;

    if (!_serverAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.serverRequired)),
      );
      return;
    }

    final source = await _pickImageSource();
    if (source == null) return;

    final picked = source == ImageSource.camera
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _reading = true);
    try {
      final data =
          await _cultivationInfoService.readFromImage(picked.path);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _cultivationData = data;
          _cultivationDataSourceUrl = null;
        });
        _offerAutoFill(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.readSuccess)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.readFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.readFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  // -- Local seed photo --

  Future<void> _saveSeedPhoto() async {
    final source = await _pickImageSource();
    if (source == null) return;

    final picked = source == ImageSource.camera
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final savedPath = await _photoService.savePhoto(picked.path);
    setState(() => _seedPhotoPaths.add(savedPath));
  }

  Future<ImageSource?> _pickImageSource() async {
    final l = AppLocalizations.of(context)!;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l.takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l.pickFromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _offerAutoFill(CultivationData data) {
    if (data.cropName.isEmpty && data.variety.isEmpty) return;

    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.autoFillConfirm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.cropName.isNotEmpty) Text('${l.cropName}: ${data.cropName}'),
            if (data.variety.isNotEmpty) Text('${l.variety}: ${data.variety}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (data.cropName.isNotEmpty && _nameCtrl.text.isEmpty) {
                  _nameCtrl.text = data.cropName;
                }
                if (data.variety.isNotEmpty && _varietyCtrl.text.isEmpty) {
                  _varietyCtrl.text = data.variety;
                }
                if (_cultivationNameCtrl.text.isEmpty) {
                  _cultivationNameCtrl.text = data.variety.isNotEmpty
                      ? '${data.cropName} ${data.variety}'
                      : data.cropName;
                }
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // -- Add web reference --

  Future<void> _addWebReference() async {
    final l = AppLocalizations.of(context)!;
    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    final result = await showDialog<_WebRef>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.addReference),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: l.referenceUrl,
                hintText: 'https://',
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: l.referenceTitle),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (urlCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                _WebRef(
                  url: urlCtrl.text.trim(),
                  title: titleCtrl.text.trim(),
                ),
              );
            },
            child: Text(l.save),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _webRefs.add(result));
    }
  }

  // -- Save --

  Future<void> _save() async {
    if (_cultivationNameCtrl.text.trim().isEmpty) return;

    setState(() => _saving = true);

    final crop = Crop(
      cultivationName: _cultivationNameCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      variety: _varietyCtrl.text.trim(),
      plotId: _selectedPlotId,
      parentCropId: _selectedParentCropId,
      memo: _memoCtrl.text.trim(),
    );

    await widget.db.insertCrop(crop);

    // Save seed packet photos
    for (var i = 0; i < _seedPhotoPaths.length; i++) {
      final ref = CropReference(
        cropId: crop.id,
        type: CropReferenceType.seedPhoto,
        filePath: _seedPhotoPaths[i],
        title: '',
        sortOrder: i,
      );
      await widget.db.insertCropReference(ref);
    }

    // Save AI-extracted cultivation info
    if (_cultivationData != null) {
      final ref = CropReference(
        cropId: crop.id,
        type: CropReferenceType.seedInfo,
        url: _cultivationDataSourceUrl,
        sourceInfoId: _cultivationData!.id,
        title: _cultivationData!.cropName.isNotEmpty
            ? '${_cultivationData!.cropName} ${_cultivationData!.variety}'.trim()
            : '',
        content: _cultivationData!.toJsonString(),
      );
      await widget.db.insertCropReference(ref);
    }

    // Save web references
    for (var i = 0; i < _webRefs.length; i++) {
      final ref = CropReference(
        cropId: crop.id,
        type: CropReferenceType.web,
        url: _webRefs[i].url,
        title: _webRefs[i].title,
        sortOrder: i,
      );
      await widget.db.insertCropReference(ref);
    }

    if (mounted) Navigator.pop(context, true);
  }

  // -- Build UI --

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.addCrop),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed:
                  _cultivationNameCtrl.text.trim().isNotEmpty ? _save : null,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Basic info section --
                  _sectionHeader(l.cultivationName, Icons.eco),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cultivationNameCtrl,
                    decoration: InputDecoration(
                      labelText: l.cultivationName,
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: l.cropName,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _varietyCtrl,
                          decoration: InputDecoration(
                            labelText: l.variety,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoCtrl,
                    decoration: InputDecoration(
                      labelText: l.memo,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  if (_allPlots.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _selectedPlotId,
                      decoration: InputDecoration(
                        labelText: l.selectPlot,
                        border: const OutlineInputBorder(),
                      ),
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
                      onChanged: (v) => setState(() => _selectedPlotId = v),
                    ),
                  ],
                  if (_allCrops.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _selectedParentCropId,
                      decoration: InputDecoration(
                        labelText: l.parentCrop,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l.nonePlot),
                        ),
                        ..._allCrops.map((c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.cultivationName),
                            )),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedParentCropId = v),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // -- Cultivation info section --
                  _sectionHeader(l.cultivationInfo, Icons.info_outline),
                  const SizedBox(height: 8),

                  if (_reading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.link, size: 18),
                        label: Text(l.readFromUrl),
                        onPressed: _reading ? null : _readFromUrl,
                      ),
                      if (_serverAvailable)
                        ActionChip(
                          avatar: const Icon(Icons.document_scanner, size: 18),
                          label: Text(l.readFromSeedPhoto),
                          onPressed: _reading ? null : _readFromSeedPhoto,
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.photo_camera, size: 18),
                        label: Text(l.saveSeedPhoto),
                        onPressed: _reading ? null : _saveSeedPhoto,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_link, size: 18),
                        label: Text(l.addReference),
                        onPressed: _reading ? null : _addWebReference,
                      ),
                    ],
                  ),

                  // AI-extracted info preview
                  if (_cultivationData != null) ...[
                    const SizedBox(height: 16),
                    _buildCultivationDataCard(l),
                  ],

                  // Seed packet photo thumbnails
                  if (_seedPhotoPaths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l.seedPacketPhotos,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _seedPhotoPaths.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_seedPhotoPaths[index]),
                                    height: 120,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() =>
                                          _seedPhotoPaths.removeAt(index));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Web references list
                  if (_webRefs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l.cultivationReferences,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...List.generate(_webRefs.length, (index) {
                      final ref = _webRefs[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.link, size: 20),
                          title: Text(
                            ref.title.isNotEmpty ? ref.title : ref.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: ref.title.isNotEmpty
                              ? Text(ref.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() => _webRefs.removeAt(index));
                            },
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _buildCultivationDataCard(AppLocalizations l) {
    final data = _cultivationData!;
    final fields = data.displayFields;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(l.cultivationInfo,
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      setState(() => _cultivationData = null),
                ),
              ],
            ),
            if (data.cropName.isNotEmpty || data.variety.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${data.cropName} ${data.variety}'.trim(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ...fields.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          field.key,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(field.value, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                )),
            if (_cultivationDataSourceUrl != null) ...[
              const SizedBox(height: 4),
              Text(
                '${l.sourceUrl}: $_cultivationDataSourceUrl',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebRef {
  final String url;
  final String title;
  _WebRef({required this.url, required this.title});
}
