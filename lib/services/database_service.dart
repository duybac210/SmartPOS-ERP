import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_receipt_model.dart';
import '../models/purchase_item_model.dart';

class DatabaseService {
  final _db = FirebaseFirestore.instance;
  final CollectionReference productCollection =
      FirebaseFirestore.instance.collection('products');

  CollectionReference get _receipts => _db.collection('purchase_receipts');

  // ─── Products ────────────────────────────────────────────────────────────────

  Future addProduct(String name, String sku, double price, int stock) async {
    return await productCollection.add({
      'name': name,
      'sku': sku,
      'price': price,
      'stock': stock,
    });
  }

  // ─── Purchase Receipts ───────────────────────────────────────────────────────

  /// Tạo phiếu nhập ở trạng thái draft
  Future<String> createPurchaseReceipt({String? note}) async {
    final now = DateTime.now();
    // Mã phiếu: PN-YYYYMMDD-HHMMSS
    final code =
        'PN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final doc = await _receipts.add({
      'code': code,
      'status': ReceiptStatus.draft.value,
      'note': note,
      'totalQty': 0,
      'totalAmount': 0.0,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return doc.id;
  }

  /// Realtime stream danh sách phiếu nhập (sắp xếp mới nhất trước)
  Stream<List<PurchaseReceipt>> getPurchaseReceipts() {
    return _receipts
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                PurchaseReceipt.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Realtime stream items của 1 phiếu
  Stream<List<PurchaseItem>> getPurchaseItems(String receiptId) {
    return _receipts
        .doc(receiptId)
        .collection('items')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                PurchaseItem.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Thêm 1 dòng hàng vào phiếu nhập + cập nhật tổng header
  Future<void> addPurchaseItem({
    required String receiptId,
    required String productId,
    required String skuSnapshot,
    required String nameSnapshot,
    required int qty,
    required double importPrice,
  }) async {
    final lineTotal = qty * importPrice;
    final itemRef = _receipts.doc(receiptId).collection('items').doc();

    // Chạy transaction để cập nhật header atomically
    await _db.runTransaction((txn) async {
      final receiptDoc = await txn.get(_receipts.doc(receiptId));
      if (!receiptDoc.exists) throw Exception('Phiếu nhập không tồn tại');

      final currentQty = (receiptDoc['totalQty'] ?? 0) as int;
      final currentAmount = (receiptDoc['totalAmount'] ?? 0.0) as num;

      txn.set(itemRef, {
        'productId': productId,
        'skuSnapshot': skuSnapshot,
        'nameSnapshot': nameSnapshot,
        'qty': qty,
        'importPrice': importPrice,
        'lineTotal': lineTotal,
      });

      txn.update(_receipts.doc(receiptId), {
        'totalQty': currentQty + qty,
        'totalAmount': currentAmount.toDouble() + lineTotal,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Xác nhận phiếu nhập:
  /// - Kiểm tra status == draft
  /// - Kiểm tra có items
  /// - Cập nhật stock từng sản phẩm + cập nhật header trong 1 batch
  Future<void> confirmPurchaseReceipt(String receiptId) async {
    final receiptRef = _receipts.doc(receiptId);
    final itemsSnap = await receiptRef.collection('items').get();

    if (itemsSnap.docs.isEmpty) {
      throw Exception('Phiếu nhập chưa có dòng hàng nào');
    }

    final receiptSnap = await receiptRef.get();
    final status = receiptSnap['status'] as String? ?? 'draft';
    if (status != 'draft') {
      throw Exception('Phiếu nhập đã được xác nhận hoặc đã huỷ');
    }

    final batch = _db.batch();
    final now = Timestamp.now();

    // Cập nhật stock từng sản phẩm
    // TODO: Tích hợp FIFO/lots khi cần quản lý lô hàng
    for (final itemDoc in itemsSnap.docs) {
      final productId = itemDoc['productId'] as String;
      final qty = (itemDoc['qty'] as num).toInt();
      batch.update(productCollection.doc(productId), {
        'stock': FieldValue.increment(qty),
      });
    }

    // Cập nhật header phiếu
    batch.update(receiptRef, {
      'status': ReceiptStatus.confirmed.value,
      'confirmedAt': now,
      'updatedAt': now,
    });

    await batch.commit();
  }
}

