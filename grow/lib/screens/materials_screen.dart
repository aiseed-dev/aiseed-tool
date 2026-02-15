import 'package:flutter/material.dart';
import '../models/farm_material.dart';
import '../services/database_service.dart';

const _categories = ['肥料', '土', '資材', '道具', 'その他'];

class MaterialsScreen extends StatefulWidget {
  final DatabaseService db;

  const MaterialsScreen({super.key, required this.db});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List<FarmMaterial> _materials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final materials = await widget.db.getFarmMaterials();
    if (!mounted) return;
    setState(() {
      _materials = materials;
      _loading = false;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showForm({FarmMaterial? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var category = existing?.category ?? '';
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    final quantityCtrl = TextEditingController(
      text: existing?.quantity?.toString() ?? '',
    );
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price?.toString() ?? '',
    );
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    var purchaseDate = existing?.purchaseDate;

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
                    existing == null ? '資材を追加' : '資材を編集',
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '資材名'),
                    autofocus: existing == null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category.isEmpty ? null : category,
                    decoration: const InputDecoration(labelText: 'カテゴリ'),
                    items: _categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
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
                          controller: unitCtrl,
                          decoration: const InputDecoration(
                            labelText: '単位',
                            hintText: '例: 袋, kg, 本',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: '価格（円）',
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
    if (nameCtrl.text.trim().isEmpty) return;

    final material = FarmMaterial(
      id: existing?.id,
      name: nameCtrl.text.trim(),
      category: category,
      vendor: vendorCtrl.text.trim(),
      purchaseDate: purchaseDate,
      quantity: int.tryParse(quantityCtrl.text),
      unit: unitCtrl.text.trim(),
      price: int.tryParse(priceCtrl.text),
      memo: memoCtrl.text.trim(),
      createdAt: existing?.createdAt,
    );

    if (existing == null) {
      await widget.db.insertFarmMaterial(material);
    } else {
      await widget.db.updateFarmMaterial(material);
    }
    _load();
  }

  Future<void> _delete(FarmMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除'),
        content: const Text('この資材を削除しますか？'),
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
    await widget.db.deleteFarmMaterial(material.id);
    _load();
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '肥料':
        return Icons.science;
      case '土':
        return Icons.landscape;
      case '資材':
        return Icons.inventory_2;
      case '道具':
        return Icons.construction;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('資材')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text('資材がありません'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _materials.length,
                  itemBuilder: (context, index) {
                    final m = _materials[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(_categoryIcon(m.category)),
                        title: Text(m.name),
                        subtitle: Text(
                          [
                            if (m.category.isNotEmpty) m.category,
                            if (m.vendor.isNotEmpty) m.vendor,
                            if (m.purchaseDate != null)
                              _formatDate(m.purchaseDate),
                            if (m.price != null) '¥${m.price}',
                            if (m.quantity != null)
                              '${m.quantity}${m.unit}',
                          ].join(' / '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showForm(existing: m),
                        onLongPress: () => _delete(m),
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
