import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/purchase_receipt_model.dart';
import '../../models/purchase_item_model.dart';
import '../../services/database_service.dart';
import 'add_purchase_item_screen.dart';

/// Màn hình chi tiết phiếu nhập:
/// - Stream header phiếu (totals cập nhật realtime)
/// - Stream danh sách items
/// - Nút "Thêm hàng" và "Xác nhận nhập" (chỉ hiện khi draft)
class PurchaseDetailScreen extends StatelessWidget {
  final String receiptId;

  const PurchaseDetailScreen({super.key, required this.receiptId});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('purchase_receipts')
          .doc(receiptId)
          .snapshots(),
      builder: (context, headerSnap) {
        if (!headerSnap.hasData || !headerSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final receipt = PurchaseReceipt.fromMap(
          headerSnap.data!.data() as Map<String, dynamic>,
          headerSnap.data!.id,
        );
        final isDraft = receipt.status == ReceiptStatus.draft;

        return Scaffold(
          appBar: AppBar(
            title: Text(receipt.code),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            actions: [
              if (isDraft)
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  tooltip: 'Thêm hàng',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddPurchaseItemScreen(receiptId: receiptId),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Header thông tin phiếu
              Container(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mã: ${receipt.code}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (receipt.note != null && receipt.note!.isNotEmpty)
                            Text('Ghi chú: ${receipt.note}'),
                        ],
                      ),
                    ),
                    _StatusBadge(status: receipt.status),
                  ],
                ),
              ),
              // Danh sách items (realtime)
              Expanded(
                child: StreamBuilder<List<PurchaseItem>>(
                  stream: db.getPurchaseItems(receiptId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có dòng hàng.\nNhấn + để thêm sản phẩm.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2,
                                color: Colors.blueAccent),
                            title: Text(item.nameSnapshot,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'SKU: ${item.skuSnapshot} | SL: ${item.qty}'),
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
              // Footer tổng + nút xác nhận
              _ReceiptFooter(receipt: receipt, db: db, isDraft: isDraft),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// Widgets phụ

class _StatusBadge extends StatelessWidget {
  final ReceiptStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case ReceiptStatus.confirmed:
        color = Colors.green;
        label = 'Đã xác nhận';
        break;
      case ReceiptStatus.cancelled:
        color = Colors.red;
        label = 'Đã huỷ';
        break;
      default:
        color = Colors.orange;
        label = 'Nháp';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _ReceiptFooter extends StatefulWidget {
  final PurchaseReceipt receipt;
  final DatabaseService db;
  final bool isDraft;

  const _ReceiptFooter({
    required this.receipt,
    required this.db,
    required this.isDraft,
  });

  @override
  State<_ReceiptFooter> createState() => _ReceiptFooterState();
}

class _ReceiptFooterState extends State<_ReceiptFooter> {
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await widget.db.confirmPurchaseReceipt(widget.receipt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác nhận nhập kho thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Quay về danh sách phiếu
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng số lượng:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${widget.receipt.totalQty}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng tiền:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${_fmt(widget.receipt.totalAmount)}đ',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.isDraft) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirming ? null : _confirm,
                icon: _confirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Xác nhận nhập kho'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
