import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/seed_packet.dart';
import '../services/database_service.dart';

class SeedPacketsScreen extends StatefulWidget {
  final DatabaseService db;

  const SeedPacketsScreen({super.key, required this.db});

  @override
  State<SeedPacketsScreen> createState() => _SeedPacketsScreenState();
}

class _SeedPacketsScreenState extends State<SeedPacketsScreen> {
  List<SeedPacket> _packets = [];
  bool _loading = true;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packets = await widget.db.getSeedPackets();
    if (!mounted) return;
    setState(() {
      _packets = packets;
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
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertSeedPacket(packet);
    } else {
      await widget.db.updateSeedPacket(packet);
    }
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
