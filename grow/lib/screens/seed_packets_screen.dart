import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/seed_packet.dart';
import '../models/crop.dart';
import '../models/crop_reference.dart';
import '../services/database_service.dart';
import '../services/photo_service.dart';

class SeedPacketsScreen extends StatefulWidget {
  final DatabaseService db;

  const SeedPacketsScreen({super.key, required this.db});

  @override
  State<SeedPacketsScreen> createState() => _SeedPacketsScreenState();
}

class _SeedPacketsScreenState extends State<SeedPacketsScreen> {
  List<SeedPacket> _packets = [];
  Map<String, Crop> _cropMap = {};
  bool _loading = true;
  final _picker = ImagePicker();
  final _photoService = PhotoService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packets = await widget.db.getSeedPackets();
    final crops = await widget.db.getCrops();
    if (!mounted) return;
    setState(() {
      _packets = packets;
      _cropMap = {for (final c in crops) c.id: c};
      _loading = false;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showForm({SeedPacket? existing}) async {
    final cropNameCtrl = TextEditingController(text: existing?.cropName ?? '');
    final varietyCtrl = TextEditingController(text: existing?.variety ?? '');
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    final quantityCtrl = TextEditingController(
      text: existing?.quantity?.toString() ?? '',
    );
    final priceCtrl = TextEditingController(
      text: existing?.price?.toString() ?? '',
    );
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    var purchaseDate = existing?.purchaseDate;
    String? photoPath = existing?.photoPath;

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
                    existing == null ? '種袋を追加' : '種袋を編集',
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  // 写真
                  if (photoPath != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photoPath!),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 150,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filledTonal(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setDialogState(() => photoPath = null),
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        final xFile = await _picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 1920,
                          imageQuality: 85,
                        );
                        if (xFile != null) {
                          setDialogState(() => photoPath = xFile.path);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('種袋を撮影'),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cropNameCtrl,
                    decoration: const InputDecoration(labelText: '品目名'),
                    autofocus: existing == null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: varietyCtrl,
                    decoration: const InputDecoration(labelText: '品種'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: vendorCtrl,
                    decoration: const InputDecoration(labelText: '購入先'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('購入日'),
                    subtitle: Text(
                      purchaseDate != null
                          ? _formatDate(purchaseDate)
                          : '未設定',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: purchaseDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => purchaseDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityCtrl,
                          decoration: const InputDecoration(labelText: '数量'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          decoration: const InputDecoration(
                            labelText: '価格（円）',
                            prefixText: '¥',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: memoCtrl,
                    decoration: const InputDecoration(labelText: 'メモ'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('キャンセル'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('保存'),
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
    if (cropNameCtrl.text.trim().isEmpty) return;

    final packet = SeedPacket(
      id: existing?.id,
      cropName: cropNameCtrl.text.trim(),
      variety: varietyCtrl.text.trim(),
      vendor: vendorCtrl.text.trim(),
      purchaseDate: purchaseDate,
      quantity: int.tryParse(quantityCtrl.text),
      price: int.tryParse(priceCtrl.text),
      memo: memoCtrl.text.trim(),
      photoPath: photoPath,
      cropId: existing?.cropId,
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertSeedPacket(packet);
    } else {
      await widget.db.updateSeedPacket(packet);
    }
    _load();
  }

  /// 種袋から栽培を新規作成する
  Future<void> _createCropFromPacket(SeedPacket packet) async {
    final cultivationName = packet.variety.isNotEmpty
        ? '${packet.cropName} ${packet.variety}'
        : packet.cropName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('栽培に登録'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「$cultivationName」を栽培として登録しますか？'),
            const SizedBox(height: 8),
            Text(
              '種袋の情報（品目名・品種）が栽培データに入力されます。',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.eco, size: 18),
            label: const Text('登録'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 栽培を作成
    final crop = Crop(
      cultivationName: cultivationName,
      name: packet.cropName,
      variety: packet.variety,
      memo: packet.vendor.isNotEmpty ? '種袋: ${packet.vendor}' : '',
    );
    await widget.db.insertCrop(crop);

    // 種袋の写真を栽培の参照として保存
    if (packet.photoPath != null) {
      final savedPath = await _photoService.savePhoto(packet.photoPath!);
      final ref = CropReference(
        cropId: crop.id,
        type: CropReferenceType.seedPhoto,
        filePath: savedPath,
        title: cultivationName,
      );
      await widget.db.insertCropReference(ref);
    }

    // 種袋にcropIdを紐付け
    final updated = packet.copyWith(cropId: crop.id);
    await widget.db.updateSeedPacket(updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$cultivationName」を栽培に登録しました')),
    );
    _load();
  }

  Future<void> _delete(SeedPacket packet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除'),
        content: const Text('この種袋を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.db.deleteSeedPacket(packet.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('種袋')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _packets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.grass,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text('種袋がありません'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _packets.length,
                  itemBuilder: (context, index) {
                    final p = _packets[index];
                    final linkedCrop =
                        p.cropId != null ? _cropMap[p.cropId] : null;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showForm(existing: p),
                        onLongPress: () => _delete(p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.photoPath != null)
                              Image.file(
                                File(p.photoPath!),
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 150,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48),
                                  ),
                                ),
                              ),
                            ListTile(
                              leading: const Icon(Icons.grass),
                              title: Text(
                                [
                                  p.cropName,
                                  if (p.variety.isNotEmpty) p.variety,
                                ].join(' '),
                              ),
                              subtitle: Text(
                                [
                                  if (p.vendor.isNotEmpty) p.vendor,
                                  if (p.purchaseDate != null)
                                    _formatDate(p.purchaseDate),
                                  if (p.price != null) '¥${p.price}',
                                  if (p.quantity != null) '${p.quantity}袋',
                                ].join(' / '),
                              ),
                            ),
                            // 栽培連携
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 12,
                              ),
                              child: linkedCrop != null
                                  ? Chip(
                                      avatar: const Icon(Icons.eco, size: 16),
                                      label: Text(
                                        linkedCrop.cultivationName,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: () =>
                                          _createCropFromPacket(p),
                                      icon: const Icon(Icons.eco, size: 18),
                                      label: const Text('栽培に登録'),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
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
