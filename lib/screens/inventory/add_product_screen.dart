import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';
import 'barcode_scanner_screen.dart';

class AddProductScreen extends StatefulWidget {
  /// Khi [product] != null thì màn hình ở chế độ chỉnh sửa
  final Product? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final skuController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();

  final DatabaseService _db = DatabaseService();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      nameController.text = widget.product!.name;
      skuController.text = widget.product!.sku;
      priceController.text = widget.product!.price.toString();
      // stock is not pre-filled – it cannot be edited here
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    skuController.dispose();
    priceController.dispose();
    stockController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      skuController.text = result;
    }
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_isEditing) {
          await _db.updateProduct(
            widget.product!.id,
            nameController.text,
            skuController.text,
            double.parse(priceController.text),
          );
        } else {
          await _db.addProduct(
            nameController.text,
            skuController.text,
            double.parse(priceController.text),
            int.parse(stockController.text),
          );
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Chỉnh sửa sản phẩm" : "Thêm sản phẩm mới"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Tên sản phẩm"),
                validator: (val) => val!.isEmpty ? "Vui lòng nhập tên" : null,
              ),
              TextFormField(
                controller: skuController,
                decoration: InputDecoration(
                  labelText: "Mã SKU / Barcode",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Quét barcode',
                    onPressed: _scanBarcode,
                  ),
                ),
                validator: (val) => val!.isEmpty ? "Vui lòng nhập SKU" : null,
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "Giá bán"),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? "Vui lòng nhập giá" : null,
              ),
              if (!_isEditing)
                TextFormField(
                  controller: stockController,
                  decoration:
                      const InputDecoration(labelText: "Số lượng nhập ban đầu"),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      val!.isEmpty ? "Vui lòng nhập số lượng" : null,
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(_isEditing ? "Lưu thay đổi" : "Xác nhận nhập kho"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
