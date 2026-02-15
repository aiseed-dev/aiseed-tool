import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sales_slip.dart';
import '../services/database_service.dart';

const _units = ['kg', 'g', '個', '本', '束', '袋', 'パック', '箱'];

class SalesSlipsScreen extends StatefulWidget {
  final DatabaseService db;

  const SalesSlipsScreen({super.key, required this.db});

  @override
  State<SalesSlipsScreen> createState() => _SalesSlipsScreenState();
}

class _SalesSlipsScreenState extends State<SalesSlipsScreen> {
  List<SalesSlip> _slips = [];
  bool _loading = true;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slips = await widget.db.getSalesSlips();
    if (!mounted) return;
    setState(() {
      _slips = slips;
      _loading = false;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showForm({SalesSlip? existing}) async {
    final customerCtrl = TextEditingController(text: existing?.customer ?? '');
    final cropNameCtrl = TextEditingController(text: existing?.cropName ?? '');
    final amountCtrl = TextEditingController(
      text: existing?.amount?.toString() ?? '',
    );
    var unit = existing?.unit ?? 'kg';
    final priceCtrl = TextEditingController(
      text: existing?.price?.toString() ?? '',
    );
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    var date = existing?.date ?? DateTime.now();
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
                    existing == null ? '売上伝票を追加' : '売上伝票を編集',
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  // 伝票写真
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
                      label: const Text('伝票を撮影'),
                    ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('売上日'),
                    subtitle: Text(_formatDate(date)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => date = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerCtrl,
                    decoration: const InputDecoration(labelText: '販売先'),
                    autofocus: existing == null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cropNameCtrl,
                    decoration: const InputDecoration(labelText: '品目名'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: amountCtrl,
                          decoration: const InputDecoration(labelText: '販売量'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: unit,
                          decoration: const InputDecoration(labelText: '単位'),
                          items: _units
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => unit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: '売上額（円）',
                      prefixText: '¥',
                    ),
                    keyboardType: TextInputType.number,
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
    if (customerCtrl.text.trim().isEmpty) return;

    final slip = SalesSlip(
      id: existing?.id,
      customer: customerCtrl.text.trim(),
      cropName: cropNameCtrl.text.trim(),
      amount: double.tryParse(amountCtrl.text),
      unit: unit,
      price: int.tryParse(priceCtrl.text),
      date: date,
      memo: memoCtrl.text.trim(),
      photoPath: photoPath,
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertSalesSlip(slip);
    } else {
      await widget.db.updateSalesSlip(slip);
    }
    _load();
  }

  Future<void> _delete(SalesSlip slip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除'),
        content: const Text('この売上伝票を削除しますか？'),
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
    await widget.db.deleteSalesSlip(slip.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('売上伝票')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.point_of_sale,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text('売上伝票がありません'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _slips.length,
                  itemBuilder: (context, index) {
                    final s = _slips[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showForm(existing: s),
                        onLongPress: () => _delete(s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (s.photoPath != null)
                              Image.file(
                                File(s.photoPath!),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            ListTile(
                              leading: const Icon(Icons.point_of_sale),
                              title: Text(
                                [
                                  s.customer,
                                  if (s.cropName.isNotEmpty) s.cropName,
                                ].join(' - '),
                              ),
                              subtitle: Text(
                                [
                                  _formatDate(s.date),
                                  if (s.amount != null)
                                    '${s.amount!.toStringAsFixed(s.amount! == s.amount!.roundToDouble() ? 0 : 1)}${s.unit}',
                                  if (s.price != null) '¥${s.price}',
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
