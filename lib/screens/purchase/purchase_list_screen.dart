import 'package:flutter/material.dart';
import '../../models/purchase_receipt_model.dart';
import '../../models/supplier_model.dart';
import '../../services/database_service.dart';
import 'purchase_detail_screen.dart';

/// Danh sách phiếu nhập hàng (realtime stream).
/// Entry point cho module Nhập hàng.
class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final DatabaseService _db = DatabaseService();
  bool _creating = false;

  Future<void> _createNewReceipt() async {
    setState(() => _creating = true);
    try {
      // Lấy danh sách nhà cung cấp
      final suppliers = await _db.getSuppliers().first;

      if (!mounted) return;

      // Dialog chọn nhà cung cấp + ghi chú
      final result = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (_) {
          final noteController = TextEditingController();
          Supplier? selectedSupplier;
          return StatefulBuilder(builder: (ctx, setStateDlg) {
            return AlertDialog(
              title: const Text('Tạo phiếu nhập mới'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Supplier>(
                    value: selectedSupplier,
                    decoration: const InputDecoration(
                      labelText: 'Nhà cung cấp (tuỳ chọn)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Supplier>(
                          value: null,
                          child: Text('-- Không chọn --')),
                      ...suppliers.map((s) => DropdownMenuItem<Supplier>(
                            value: s,
                            child: Text(s.name),
                          )),
                    ],
                    onChanged: (v) =>
                        setStateDlg(() => selectedSupplier = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      hintText: 'Ghi chú (tuỳ chọn)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'note': noteController.text,
                    'supplier': selectedSupplier,
                  }),
                  child: const Text('Tạo phiếu'),
                ),
              ],
            );
          });
        },
      );

      if (result == null) return;

      final note = (result['note'] as String).trim();
      final supplier = result['supplier'] as Supplier?;

      final receiptId = await _db.createPurchaseReceipt(
        note: note.isEmpty ? null : note,
        supplierId: supplier?.id,
        supplierName: supplier?.name,
      );

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PurchaseDetailScreen(receiptId: receiptId),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiếu Nhập Hàng'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PurchaseReceipt>>(
        stream: _db.getPurchaseReceipts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final receipts = snapshot.data!;
          if (receipts.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có phiếu nhập.\nNhấn + để tạo phiếu mới.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (_, i) {
              final r = receipts[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: _statusIcon(r.status),
                  title: Text(r.code,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'SL: ${r.totalQty} | Tổng: ${_fmt(r.totalAmount)}đ'
                      '${r.note != null && r.note!.isNotEmpty ? "\n${r.note}" : ""}'),
                  trailing: Text(
                    _statusLabel(r.status),
                    style: TextStyle(
                        color: _statusColor(r.status),
                        fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchaseDetailScreen(receiptId: r.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _creating ? null : _createNewReceipt,
        tooltip: 'Tạo phiếu nhập mới',
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

  Icon _statusIcon(ReceiptStatus status) {
    switch (status) {
      case ReceiptStatus.confirmed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case ReceiptStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.edit_note, color: Colors.orange);
    }
  }

  String _statusLabel(ReceiptStatus status) {
    switch (status) {
      case ReceiptStatus.confirmed:
        return 'Đã xác nhận';
      case ReceiptStatus.cancelled:
        return 'Đã huỷ';
      default:
        return 'Nháp';
    }
  }

  Color _statusColor(ReceiptStatus status) {
    switch (status) {
      case ReceiptStatus.confirmed:
        return Colors.green;
      case ReceiptStatus.cancelled:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _fmt(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}


