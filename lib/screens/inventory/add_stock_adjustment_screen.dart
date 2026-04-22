import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';

const _reasons = [
  'Kiểm kê',
  'Hư hỏng / hết hạn',
  'Điều chỉnh lỗi nhập',
  'Quà tặng / dùng nội bộ',
  'Khác',
];

class AddStockAdjustmentScreen extends StatefulWidget {
  const AddStockAdjustmentScreen({super.key});

  @override
  State<AddStockAdjustmentScreen> createState() =>
      _AddStockAdjustmentScreenState();
}

class _AddStockAdjustmentScreenState extends State<AddStockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deltaController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();

  Product? _selectedProduct;
  String _searchQuery = '';
  String _selectedReason = _reasons.first;
  bool _isDecrease = false;
  bool _loading = false;

  @override
  void dispose() {
    _deltaController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sản phẩm')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final delta = int.parse(_deltaController.text);
      await DatabaseService().createStockAdjustment(
        productId: _selectedProduct!.id,
        productNameSnapshot: _selectedProduct!.name,
        delta: _isDecrease ? -delta : delta,
        reason: _selectedReason,
        note: _noteController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Điều chỉnh tồn kho thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều Chỉnh Tồn Kho'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chọn sản phẩm
              const Text('Chọn sản phẩm',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên hoặc SKU...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      if (_searchQuery.isEmpty) return true;
                      return (data['name'] as String? ?? '')
                              .toLowerCase()
                              .contains(_searchQuery) ||
                          (data['sku'] as String? ?? '')
                              .toLowerCase()
                              .contains(_searchQuery);
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('Không tìm thấy sản phẩm'));
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final p = Product.fromMap(
                            docs[i].data() as Map<String, dynamic>,
                            docs[i].id);
                        final selected = _selectedProduct?.id == p.id;
                        return ListTile(
                          dense: true,
                          tileColor: selected ? Colors.blue.shade50 : null,
                          leading: Icon(Icons.inventory_2,
                              color:
                                  selected ? Colors.blue : Colors.grey),
                          title: Text(p.name),
                          subtitle: Text('SKU: ${p.sku} | Tồn: ${p.stock}'),
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.blue)
                              : null,
                          onTap: () =>
                              setState(() => _selectedProduct = p),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_selectedProduct != null) ...[
                const Divider(),
                Text('Sản phẩm: ${_selectedProduct!.name}  (Tồn: ${_selectedProduct!.stock})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                // Loại điều chỉnh
                Row(
                  children: [
                    const Text('Loại: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Tăng'),
                      selected: !_isDecrease,
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) =>
                          setState(() => _isDecrease = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Giảm'),
                      selected: _isDecrease,
                      selectedColor: Colors.red.shade100,
                      onSelected: (_) =>
                          setState(() => _isDecrease = true),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _deltaController,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng điều chỉnh',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Nhập số > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedReason,
                        decoration: const InputDecoration(
                          labelText: 'Lý do',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _reasons
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedReason = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Xác nhận điều chỉnh'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
