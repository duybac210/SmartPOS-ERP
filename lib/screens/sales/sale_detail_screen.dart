import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/sale_order_model.dart';
import '../../models/sale_item_model.dart';
import '../../services/database_service.dart';
import 'create_sale_screen.dart';

/// Màn hình xem chi tiết đơn bán (chỉ đọc với đơn đã thanh toán/huỷ,
/// hoặc chuyển sang CreateSaleScreen để sửa nếu còn draft).
class SaleDetailScreen extends StatelessWidget {
  final String orderId;
  const SaleDetailScreen({super.key, required this.orderId});

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sale_orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, headerSnap) {
        if (!headerSnap.hasData || !headerSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final order = SaleOrder.fromMap(
          headerSnap.data!.data() as Map<String, dynamic>,
          headerSnap.data!.id,
        );
        final isDraft = order.status == SaleStatus.draft;

        return Scaffold(
          appBar: AppBar(
            title: Text(order.code),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            actions: [
              if (isDraft)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Tiếp tục chỉnh sửa',
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateSaleScreen(orderId: orderId),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Header info
              Container(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mã: ${order.code}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        _StatusBadge(status: order.status),
                      ],
                    ),
                    if (order.customerName != null)
                      Text('Khách: ${order.customerName}'),
                    Text(
                        'Phương thức: ${order.paymentMethod.label}'),
                    if (order.paidAt != null)
                      Text(
                          'Thanh toán lúc: ${_fmtDate(order.paidAt!)}'),
                    if (order.note != null && order.note!.isNotEmpty)
                      Text('Ghi chú: ${order.note}'),
                  ],
                ),
              ),
              // Danh sách items
              Expanded(
                child: StreamBuilder<List<SaleItem>>(
                  stream: db.getSaleItems(orderId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const Center(child: Text('Không có sản phẩm'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          child: ListTile(
                            title: Text(item.nameSnapshot,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${_fmt(item.priceSnapshot)}đ × ${item.qty}'),
                            trailing: Text(
                              '${_fmt(item.lineTotal)}đ',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Footer tổng
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(blurRadius: 4, color: Colors.black12)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng cộng:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_fmt(order.totalAmount)}đ'),
                      ],
                    ),
                    if (order.discount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Chiết khấu:'),
                          Text('- ${_fmt(order.discount)}đ',
                              style:
                                  const TextStyle(color: Colors.orange)),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thành tiền:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text(
                          '${_fmt(order.finalAmount)}đ',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SaleStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case SaleStatus.paid:
        color = Colors.green;
        label = 'Đã thanh toán';
        break;
      case SaleStatus.cancelled:
        color = Colors.red;
        label = 'Đã huỷ';
        break;
      default:
        color = Colors.orange;
        label = 'Nháp';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
