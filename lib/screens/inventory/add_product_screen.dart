import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

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

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _db.addProduct(
          nameController.text,
          skuController.text,
          double.parse(priceController.text),
          int.parse(stockController.text),
        );
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
      appBar: AppBar(title: const Text("Nhập Hàng Mới")),
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
                decoration: const InputDecoration(
                  labelText: "Mã SKU / Barcode",
                ),
                validator: (val) => val!.isEmpty ? "Vui lòng nhập SKU" : null,
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "Giá bán"),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? "Vui lòng nhập giá" : null,
              ),
              TextFormField(
                controller: stockController,
                decoration: const InputDecoration(labelText: "Số lượng nhập"),
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
                child: const Text("Xác nhận nhập kho"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
