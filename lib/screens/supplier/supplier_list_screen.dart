import 'package:flutter/material.dart';
import '../../models/supplier_model.dart';
import '../../services/database_service.dart';
import 'add_supplier_screen.dart';

class SupplierListScreen extends StatelessWidget {
  const SupplierListScreen({super.key});

  Future<void> _deleteSupplier(
      BuildContext context, Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá nhà cung cấp'),
        content: Text(
            'Bạn có chắc muốn xoá "${supplier.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DatabaseService().deleteSupplier(supplier.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhà Cung Cấp'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Supplier>>(
        stream: db.getSuppliers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final suppliers = snapshot.data!;
          if (suppliers.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có nhà cung cấp.\nNhấn + để thêm mới.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (_, i) {
              final s = suppliers[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.business, color: Colors.blueAccent),
                  title: Text(s.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    if (s.phone != null && s.phone!.isNotEmpty) '📞 ${s.phone}',
                    if (s.email != null && s.email!.isNotEmpty) '✉ ${s.email}',
                    if (s.address != null && s.address!.isNotEmpty)
                      '📍 ${s.address}',
                  ].join('  ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        tooltip: 'Chỉnh sửa',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddSupplierScreen(supplier: s),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Xoá',
                        onPressed: () => _deleteSupplier(context, s),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSupplierScreen()),
        ),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
