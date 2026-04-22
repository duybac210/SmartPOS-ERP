import 'package:flutter/material.dart';
import '../../models/sale_order_model.dart';
import '../../services/database_service.dart';
import 'create_sale_screen.dart';
import 'sale_detail_screen.dart';

class SaleListScreen extends StatefulWidget {
  const SaleListScreen({super.key});

  @override
  State<SaleListScreen> createState() => _SaleListScreenState();
}

class _SaleListScreenState extends State<SaleListScreen> {
  final DatabaseService _db = DatabaseService();
  bool _creating = false;

  Future<void> _createNewOrder() async {
    setState(() => _creating = true);
    try {
      final orderId = await _db.createSaleOrder();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateSaleScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn Bán Hàng'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SaleOrder>>(
        stream: _db.getSaleOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có đơn bán hàng.\nNhấn + để tạo đơn mới.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: _statusIcon(o.status),
                  title: Text(o.code,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'SL: ${o.totalQty} | ${_fmt(o.finalAmount)}đ'
                    '${o.customerName != null ? "\n${o.customerName}" : ""}',
                  ),
                  trailing: Text(
                    _statusLabel(o.status),
                    style: TextStyle(
                        color: _statusColor(o.status),
                        fontWeight: FontWeight.bold),
                  ),
                  isThreeLine: o.customerName != null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SaleDetailScreen(orderId: o.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _creating ? null : _createNewOrder,
        tooltip: 'Tạo đơn bán hàng mới',
        backgroundColor: Colors.blueAccent,
        child: _creating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Icon _statusIcon(SaleStatus status) {
    switch (status) {
      case SaleStatus.paid:
        return const Icon(Icons.check_circle, color: Colors.green);
      case SaleStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.shopping_cart, color: Colors.orange);
    }
  }

  String _statusLabel(SaleStatus status) {
    switch (status) {
      case SaleStatus.paid:
        return 'Đã TT';
      case SaleStatus.cancelled:
        return 'Đã huỷ';
      default:
        return 'Nháp';
    }
  }

  Color _statusColor(SaleStatus status) {
    switch (status) {
      case SaleStatus.paid:
        return Colors.green;
      case SaleStatus.cancelled:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
