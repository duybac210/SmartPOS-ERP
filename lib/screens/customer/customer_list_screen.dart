import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../services/database_service.dart';
import 'add_customer_screen.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Future<void> _deleteCustomer(
      BuildContext context, Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá khách hàng'),
        content: Text('Xoá khách hàng "${customer.name}"?'),
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
        await DatabaseService().deleteCustomer(customer.id);
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
        title: const Text('Khách Hàng'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Customer>>(
        stream: db.getCustomers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = snapshot.data!;
          if (customers.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có khách hàng.\nNhấn + để thêm mới.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (_, i) {
              final c = customers[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    if (c.phone != null && c.phone!.isNotEmpty)
                      '📞 ${c.phone}',
                    '💰 ${_fmt(c.totalSpent)}đ | ⭐ ${c.points} điểm',
                  ].join('\n')),
                  isThreeLine: c.phone != null && c.phone!.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        tooltip: 'Chỉnh sửa',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddCustomerScreen(customer: c),
                          ),
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Xoá',
                        onPressed: () => _deleteCustomer(context, c),
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
          MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
        ),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
