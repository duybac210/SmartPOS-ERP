import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../models/customer_model.dart';
import '../../models/sale_order_model.dart';
import '../../services/database_service.dart';

/// Màn hình tạo / chỉnh sửa đơn bán hàng (POS cart)
/// - Chọn sản phẩm (search realtime)
/// - Hiển thị giỏ hàng live
/// - Chọn khách hàng (tuỳ chọn)
/// - Nhập chiết khấu
/// - Chọn phương thức thanh toán
/// - Nút xác nhận thanh toán
class CreateSaleScreen extends StatefulWidget {
  final String orderId;
  const CreateSaleScreen({super.key, required this.orderId});

  @override
  State<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends State<CreateSaleScreen> {
  final DatabaseService _db = DatabaseService();
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  String _searchQuery = '';
  bool _confirming = false;

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  // ── Thêm sản phẩm vào đơn ────────────────────────────────────────────────
  Future<void> _addProduct(Product product) async {
    final qtyResult = await showDialog<int>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController(text: '1');
        return AlertDialog(
          title: Text(product.name),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số lượng'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text);
                if (n != null && n > 0) Navigator.pop(context, n);
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
    if (qtyResult == null) return;
    if (product.stock < qtyResult) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Tồn kho không đủ (hiện có: ${product.stock})')),
        );
      }
      return;
    }
    try {
      await _db.addSaleItem(
        orderId: widget.orderId,
        productId: product.id,
        nameSnapshot: product.name,
        priceSnapshot: product.price,
        qty: qtyResult,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  // ── Chọn khách hàng ───────────────────────────────────────────────────────
  Future<void> _pickCustomer() async {
    final customers = await FirebaseFirestore.instance
        .collection('customers')
        .orderBy('name')
        .get();
    if (!mounted) return;

    final selected = await showDialog<Customer>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Chọn khách hàng'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: customers.docs.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return ListTile(
                    leading: const Icon(Icons.person_off),
                    title: const Text('Không chọn (khách lẻ)'),
                    onTap: () => Navigator.pop(context, null),
                  );
                }
                final c = Customer.fromMap(
                    customers.docs[i - 1].data(), customers.docs[i - 1].id);
                return ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.person, size: 16)),
                  title: Text(c.name),
                  subtitle: Text(c.phone ?? ''),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        );
      },
    );

    // null means "no customer" (khách lẻ)
    final customerId = selected?.id;
    final customerName = selected?.name;
    await FirebaseFirestore.instance
        .collection('sale_orders')
        .doc(widget.orderId)
        .update({
      'customerId': customerId,
      'customerName': customerName,
      'updatedAt': Timestamp.now(),
    });
  }

  // ── Xác nhận thanh toán ───────────────────────────────────────────────────
  Future<void> _confirmPayment(SaleOrder order) async {
    final payMethods = PaymentMethod.values;
    PaymentMethod selected = order.paymentMethod;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setStateDlg) {
          return AlertDialog(
            title: const Text('Xác nhận thanh toán'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tổng tiền: ${_fmt(order.finalAmount)}đ',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('Phương thức thanh toán:'),
                ...payMethods.map((m) => RadioListTile<PaymentMethod>(
                      title: Text(m.label),
                      value: m,
                      groupValue: selected,
                      onChanged: (v) => setStateDlg(() => selected = v!),
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                child: const Text('Thanh toán'),
              ),
            ],
          );
        });
      },
    );

    if (confirmed != true) return;

    setState(() => _confirming = true);
    try {
      await _db.updateSalePaymentMethod(widget.orderId, selected);
      await _db.confirmSaleOrder(widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanh toán thành công!'),
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
      if (mounted) setState(() => _confirming = false);
    }
  }

  // ── Huỷ đơn ──────────────────────────────────────────────────────────────
  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ đơn hàng'),
        content: const Text('Bạn có chắc muốn huỷ đơn này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Huỷ đơn', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _db.cancelSaleOrder(widget.orderId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sale_orders')
          .doc(widget.orderId)
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
                  icon: const Icon(Icons.person_add_alt),
                  tooltip: 'Chọn khách hàng',
                  onPressed: _pickCustomer,
                ),
              if (isDraft)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined),
                  tooltip: 'Huỷ đơn',
                  onPressed: _cancelOrder,
                ),
            ],
          ),
          body: Column(
            children: [
              // ── Tìm kiếm & thêm sản phẩm ───────────────────────────────
              if (isDraft) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Tìm sản phẩm để thêm...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  SizedBox(
                    height: 160,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final docs = snapshot.data!.docs.where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          return (data['name'] as String? ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              (data['sku'] as String? ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery);
                        }).toList();
                        if (docs.isEmpty) {
                          return const Center(
                              child: Text('Không tìm thấy'));
                        }
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final p = Product.fromMap(
                                docs[i].data() as Map<String, dynamic>,
                                docs[i].id);
                            return ListTile(
                              dense: true,
                              title: Text(p.name),
                              subtitle:
                                  Text('${_fmt(p.price)}đ | Tồn: ${p.stock}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle,
                                    color: Colors.blueAccent),
                                onPressed: p.stock > 0
                                    ? () => _addProduct(p)
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),
              ],
              // ── Thông tin khách hàng ────────────────────────────────────
              if (order.customerName != null)
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18,
                          color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(order.customerName!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              // ── Danh sách items ─────────────────────────────────────────
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('sale_orders')
                      .doc(widget.orderId)
                      .collection('items')
                      .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Giỏ hàng trống.\nTìm và thêm sản phẩm ở trên.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data =
                            docs[i].data() as Map<String, dynamic>;
                        final itemId = docs[i].id;
                        final name = data['nameSnapshot'] ?? '';
                        final qty = (data['qty'] ?? 0) as int;
                        final price =
                            (data['priceSnapshot'] ?? 0).toDouble();
                        final lineTotal =
                            (data['lineTotal'] ?? 0).toDouble();

                        final tile = Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          child: ListTile(
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${_fmt(price)}đ × $qty'),
                            trailing: Text(
                              '${_fmt(lineTotal)}đ',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        );

                        if (!isDraft) return tile;

                        return Dismissible(
                          key: ValueKey(itemId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade100,
                            child:
                                const Icon(Icons.delete, color: Colors.red),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Xoá sản phẩm'),
                                content:
                                    Text('Xoá "$name" khỏi đơn hàng?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Huỷ'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Xoá',
                                        style: TextStyle(
                                            color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) async {
                            try {
                              await _db.deleteSaleItem(
                                orderId: widget.orderId,
                                itemId: itemId,
                                qty: qty,
                                lineTotal: lineTotal,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi: $e')));
                              }
                            }
                          },
                          child: tile,
                        );
                      },
                    );
                  },
                ),
              ),
              // ── Footer: chiết khấu + thanh toán ────────────────────────
              _SaleFooter(
                order: order,
                isDraft: isDraft,
                discountController: _discountController,
                db: _db,
                onConfirm: () => _confirmPayment(order),
                confirming: _confirming,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SaleFooter extends StatelessWidget {
  final SaleOrder order;
  final bool isDraft;
  final TextEditingController discountController;
  final DatabaseService db;
  final VoidCallback onConfirm;
  final bool confirming;

  const _SaleFooter({
    required this.order,
    required this.isDraft,
    required this.discountController,
    required this.db,
    required this.onConfirm,
    required this.confirming,
  });

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
              const Text('Tổng cộng:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${_fmt(order.totalAmount)}đ'),
            ],
          ),
          if (isDraft) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Chiết khấu (đ): ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) async {
                      final d = double.tryParse(v) ?? 0;
                      try {
                        await db.updateSaleDiscount(order.id, d);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e')));
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thành tiền:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                '${_fmt(order.finalAmount)}đ',
                style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
          if (isDraft) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: confirming ? null : onConfirm,
                icon: confirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payment),
                label: const Text('Thanh toán'),
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
