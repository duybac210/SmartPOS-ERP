import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';
import '../inventory/barcode_scanner_screen.dart';

/// Màn hình thêm dòng hàng vào phiếu nhập.
/// Cho phép chọn sản phẩm (có search + quét barcode), nhập qty và importPrice.
class AddPurchaseItemScreen extends StatefulWidget {
  final String receiptId;

  const AddPurchaseItemScreen({super.key, required this.receiptId});

  @override
  State<AddPurchaseItemScreen> createState() => _AddPurchaseItemScreenState();
}

class _AddPurchaseItemScreenState extends State<AddPurchaseItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();

  final DatabaseService _db = DatabaseService();

  Product? _selectedProduct;
  String _searchQuery = '';
  bool _loading = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _searchQuery = result;
        _searchController.text = result;
      });
    }
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
      await _db.addPurchaseItem(
        receiptId: widget.receiptId,
        productId: _selectedProduct!.id,
        skuSnapshot: _selectedProduct!.sku,
        nameSnapshot: _selectedProduct!.name,
        qty: int.parse(_qtyController.text),
        importPrice: double.parse(_priceController.text),
      );
      if (mounted) Navigator.pop(context);
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
        title: const Text('Thêm hàng vào phiếu'),
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
              // ── Chọn sản phẩm ──────────────────────────────────────────────
              const Text(
                'Chọn sản phẩm',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc SKU...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Quét barcode',
                    onPressed: _scanBarcode,
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
                      final q = _searchQuery.toLowerCase();
                      if (q.isEmpty) return true;
                      return (data['name'] as String? ?? '')
                              .toLowerCase()
                              .contains(q) ||
                          (data['sku'] as String? ?? '')
                              .toLowerCase()
                              .contains(q);
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('Không tìm thấy sản phẩm'));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final p = Product.fromMap(
                            d.data() as Map<String, dynamic>, d.id);
                        final selected = _selectedProduct?.id == p.id;
                        return ListTile(
                          dense: true,
                          tileColor:
                              selected ? Colors.blue.shade50 : null,
                          leading: Icon(Icons.inventory_2,
                              color: selected
                                  ? Colors.blue
                                  : Colors.grey),
                          title: Text(p.name),
                          subtitle: Text('SKU: ${p.sku} | Tồn: ${p.stock}'),
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.blue)
                              : null,
                          onTap: () => setState(() => _selectedProduct = p),
                        );
                      },
                    );
                  },
                ),
              ),
              // ── Số lượng & giá nhập ────────────────────────────────────────
              if (_selectedProduct != null) ...[
                const Divider(),
                Text(
                  'Sản phẩm: ${_selectedProduct!.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Số lượng > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Giá nhập (đ)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Giá >= 0';
                          return null;
                        },
                      ),
                    ),
                  ],
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
                        : const Icon(Icons.add),
                    label: const Text('Thêm vào phiếu'),
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
