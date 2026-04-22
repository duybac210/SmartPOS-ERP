import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_receipt_model.dart';
import '../models/purchase_item_model.dart';
import '../models/supplier_model.dart';
import '../models/category_model.dart';
import '../models/stock_adjustment_model.dart';
import '../models/customer_model.dart';
import '../models/sale_order_model.dart';
import '../models/sale_item_model.dart';

class DatabaseService {
  final _db = FirebaseFirestore.instance;
  final CollectionReference productCollection =
      FirebaseFirestore.instance.collection('products');

  /// Số tiền chi tiêu (đ) để tích 1 điểm thưởng
  static const int loyaltyPointsDivisor = 10000;

  CollectionReference get _receipts => _db.collection('purchase_receipts');
  CollectionReference get _suppliers => _db.collection('suppliers');
  CollectionReference get _categories => _db.collection('categories');
  CollectionReference get _adjustments => _db.collection('stock_adjustments');
  CollectionReference get _customers => _db.collection('customers');
  CollectionReference get _saleOrders => _db.collection('sale_orders');

  // ─── Products ────────────────────────────────────────────────────────────────

  Future addProduct(String name, String sku, double price, int stock,
      {String? categoryId, String? categoryName}) async {
    return await productCollection.add({
      'name': name,
      'sku': sku,
      'price': price,
      'stock': stock,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryName != null) 'categoryName': categoryName,
    });
  }

  Future<void> updateProduct(
      String id, String name, String sku, double price,
      {String? categoryId, String? categoryName}) async {
    // stock is intentionally excluded – it is only modified via purchase receipts or adjustments
    await productCollection.doc(id).update({
      'name': name,
      'sku': sku,
      'price': price,
      'categoryId': categoryId,
      'categoryName': categoryName,
    });
  }

  Future<void> deleteProduct(String id) async {
    await productCollection.doc(id).delete();
  }

  // ─── Suppliers ───────────────────────────────────────────────────────────────

  Stream<List<Supplier>> getSuppliers() {
    return _suppliers
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Supplier.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<String> addSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final doc = await _suppliers.add({
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (address != null && address.isNotEmpty) 'address': address,
      'createdAt': Timestamp.now(),
    });
    return doc.id;
  }

  Future<void> updateSupplier(
      String id, String name, String? phone, String? email, String? address) async {
    await _suppliers.doc(id).update({
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
    });
  }

  Future<void> deleteSupplier(String id) async {
    await _suppliers.doc(id).delete();
  }

  // ─── Categories ──────────────────────────────────────────────────────────────

  Stream<List<Category>> getCategories() {
    return _categories
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                Category.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<String> addCategory(String name, {String? description}) async {
    final doc = await _categories.add({
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    return doc.id;
  }

  Future<void> updateCategory(String id, String name,
      {String? description}) async {
    await _categories.doc(id).update({
      'name': name,
      'description': description,
    });
  }

  Future<void> deleteCategory(String id) async {
    await _categories.doc(id).delete();
  }

  // ─── Stock Adjustments ───────────────────────────────────────────────────────

  Stream<List<StockAdjustment>> getStockAdjustments() {
    return _adjustments
        .orderBy('adjustedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StockAdjustment.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Tạo phiếu điều chỉnh tồn kho và cập nhật stock sản phẩm atomically
  Future<void> createStockAdjustment({
    required String productId,
    required String productNameSnapshot,
    required int delta,
    required String reason,
    String? note,
  }) async {
    if (delta == 0) throw Exception('Điều chỉnh phải khác 0');
    final productRef = productCollection.doc(productId);

    await _db.runTransaction((txn) async {
      final productDoc = await txn.get(productRef);
      if (!productDoc.exists) throw Exception('Sản phẩm không tồn tại');
      final currentStock = (productDoc['stock'] ?? 0) as int;
      if (currentStock + delta < 0) {
        throw Exception('Tồn kho không đủ (tồn hiện tại: $currentStock)');
      }

      final adjRef = _adjustments.doc();
      txn.set(adjRef, {
        'productId': productId,
        'productNameSnapshot': productNameSnapshot,
        'delta': delta,
        'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
        'adjustedAt': Timestamp.now(),
      });

      txn.update(productRef, {
        'stock': FieldValue.increment(delta),
      });
    });
  }

  // ─── Customers ───────────────────────────────────────────────────────────────

  Stream<List<Customer>> getCustomers() {
    return _customers
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                Customer.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<String> addCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final doc = await _customers.add({
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (address != null && address.isNotEmpty) 'address': address,
      'points': 0,
      'totalSpent': 0.0,
      'createdAt': Timestamp.now(),
    });
    return doc.id;
  }

  Future<void> updateCustomer(
      String id, String name, String? phone, String? email,
      String? address) async {
    await _customers.doc(id).update({
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
    });
  }

  Future<void> deleteCustomer(String id) async {
    await _customers.doc(id).delete();
  }

  // ─── Sale Orders ─────────────────────────────────────────────────────────────

  Stream<List<SaleOrder>> getSaleOrders() {
    return _saleOrders
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                SaleOrder.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<List<SaleItem>> getSaleItems(String orderId) {
    return _saleOrders
        .doc(orderId)
        .collection('items')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                SaleItem.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Tạo đơn bán hàng ở trạng thái draft
  Future<String> createSaleOrder({
    String? customerId,
    String? customerName,
    String? note,
  }) async {
    final now = DateTime.now();
    final code =
        'HD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final doc = await _saleOrders.add({
      'code': code,
      'status': SaleStatus.draft.value,
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      'totalQty': 0,
      'totalAmount': 0.0,
      'discount': 0.0,
      'finalAmount': 0.0,
      'paymentMethod': PaymentMethod.cash.value,
      if (note != null && note.isNotEmpty) 'note': note,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return doc.id;
  }

  /// Thêm dòng hàng vào đơn bán
  Future<void> addSaleItem({
    required String orderId,
    required String productId,
    required String nameSnapshot,
    required double priceSnapshot,
    required int qty,
  }) async {
    final lineTotal = qty * priceSnapshot;
    final itemRef = _saleOrders.doc(orderId).collection('items').doc();

    await _db.runTransaction((txn) async {
      final orderDoc = await txn.get(_saleOrders.doc(orderId));
      if (!orderDoc.exists) throw Exception('Đơn hàng không tồn tại');

      final currentQty = (orderDoc['totalQty'] ?? 0) as int;
      final currentAmount = (orderDoc['totalAmount'] ?? 0.0) as num;
      final discount = (orderDoc['discount'] ?? 0.0) as num;

      final newTotal = currentAmount.toDouble() + lineTotal;

      txn.set(itemRef, {
        'productId': productId,
        'nameSnapshot': nameSnapshot,
        'priceSnapshot': priceSnapshot,
        'qty': qty,
        'lineTotal': lineTotal,
      });

      txn.update(_saleOrders.doc(orderId), {
        'totalQty': currentQty + qty,
        'totalAmount': newTotal,
        'finalAmount': (newTotal - discount.toDouble()).clamp(0.0, double.infinity),
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Xoá dòng hàng khỏi đơn bán
  Future<void> deleteSaleItem({
    required String orderId,
    required String itemId,
    required int qty,
    required double lineTotal,
  }) async {
    final orderRef = _saleOrders.doc(orderId);
    final itemRef = orderRef.collection('items').doc(itemId);

    await _db.runTransaction((txn) async {
      final orderDoc = await txn.get(orderRef);
      if (!orderDoc.exists) throw Exception('Đơn hàng không tồn tại');
      if ((orderDoc['status'] as String? ?? 'draft') != 'draft') {
        throw Exception('Không thể xoá dòng hàng của đơn đã thanh toán');
      }

      final currentQty = (orderDoc['totalQty'] ?? 0) as int;
      final currentAmount = (orderDoc['totalAmount'] ?? 0.0) as num;
      final discount = (orderDoc['discount'] ?? 0.0) as num;
      final newTotal =
          (currentAmount.toDouble() - lineTotal).clamp(0.0, double.infinity);

      txn.delete(itemRef);
      txn.update(orderRef, {
        'totalQty': (currentQty - qty).clamp(0, currentQty),
        'totalAmount': newTotal,
        'finalAmount': (newTotal - discount.toDouble()).clamp(0.0, double.infinity),
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Cập nhật chiết khấu của đơn bán
  Future<void> updateSaleDiscount(String orderId, double discount) async {
    final orderRef = _saleOrders.doc(orderId);
    final snap = await orderRef.get();
    final totalAmount = (snap['totalAmount'] ?? 0.0) as num;
    final finalAmount =
        (totalAmount.toDouble() - discount).clamp(0.0, double.infinity);
    await orderRef.update({
      'discount': discount,
      'finalAmount': finalAmount,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Cập nhật phương thức thanh toán
  Future<void> updateSalePaymentMethod(
      String orderId, PaymentMethod method) async {
    await _saleOrders.doc(orderId).update({
      'paymentMethod': method.value,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Xác nhận thanh toán đơn bán:
  /// - Trừ tồn kho từng sản phẩm
  /// - Cập nhật totalSpent và points khách hàng
  /// - Cập nhật status = paid
  Future<void> confirmSaleOrder(String orderId) async {
    final orderRef = _saleOrders.doc(orderId);
    final itemsSnap = await orderRef.collection('items').get();

    if (itemsSnap.docs.isEmpty) {
      throw Exception('Đơn hàng chưa có sản phẩm nào');
    }

    final orderSnap = await orderRef.get();
    final status = orderSnap['status'] as String? ?? 'draft';
    if (status != 'draft') {
      throw Exception('Đơn hàng đã thanh toán hoặc đã huỷ');
    }

    final batch = _db.batch();
    final now = Timestamp.now();

    // Trừ tồn kho
    for (final itemDoc in itemsSnap.docs) {
      final productId = itemDoc['productId'] as String;
      final qty = (itemDoc['qty'] as num).toInt();
      batch.update(productCollection.doc(productId), {
        'stock': FieldValue.increment(-qty),
      });
    }

    // Cập nhật header đơn hàng
    final finalAmount = (orderSnap['finalAmount'] ?? 0.0) as num;
    batch.update(orderRef, {
      'status': SaleStatus.paid.value,
      'paidAt': now,
      'updatedAt': now,
    });

    // Cập nhật khách hàng nếu có
    final customerId = orderSnap['customerId'] as String?;
    if (customerId != null) {
      final pointsEarned =
          (finalAmount.toDouble() / loyaltyPointsDivisor).floor();
      batch.update(_customers.doc(customerId), {
        'totalSpent': FieldValue.increment(finalAmount.toDouble()),
        'points': FieldValue.increment(pointsEarned),
      });
    }

    await batch.commit();
  }

  /// Huỷ đơn bán (chỉ khi đang draft)
  Future<void> cancelSaleOrder(String orderId) async {
    final orderRef = _saleOrders.doc(orderId);
    final snap = await orderRef.get();
    final status = snap['status'] as String? ?? 'draft';
    if (status != 'draft') {
      throw Exception('Chỉ có thể huỷ đơn đang ở trạng thái nháp');
    }
    await orderRef.update({
      'status': SaleStatus.cancelled.value,
      'updatedAt': Timestamp.now(),
    });
  }

  // ─── Purchase Receipts ───────────────────────────────────────────────────────

  /// Tạo phiếu nhập ở trạng thái draft
  Future<String> createPurchaseReceipt({
    String? note,
    String? supplierId,
    String? supplierName,
  }) async {
    final now = DateTime.now();
    // Mã phiếu: PN-YYYYMMDD-HHMMSS
    final code =
        'PN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final doc = await _receipts.add({
      'code': code,
      'status': ReceiptStatus.draft.value,
      'note': note,
      if (supplierId != null) 'supplierId': supplierId,
      if (supplierName != null) 'supplierName': supplierName,
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

  /// Huỷ phiếu nhập (chỉ được huỷ khi đang ở trạng thái draft)
  Future<void> cancelPurchaseReceipt(String receiptId) async {
    final receiptRef = _receipts.doc(receiptId);
    final snap = await receiptRef.get();
    final status = snap['status'] as String? ?? 'draft';
    if (status != 'draft') {
      throw Exception('Chỉ có thể huỷ phiếu đang ở trạng thái nháp');
    }
    await receiptRef.update({
      'status': ReceiptStatus.cancelled.value,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Xoá một dòng hàng khỏi phiếu nhập + cập nhật tổng header
  Future<void> deletePurchaseItem({
    required String receiptId,
    required String itemId,
    required int qty,
    required double lineTotal,
  }) async {
    final receiptRef = _receipts.doc(receiptId);
    final itemRef = receiptRef.collection('items').doc(itemId);

    await _db.runTransaction((txn) async {
      final receiptDoc = await txn.get(receiptRef);
      if (!receiptDoc.exists) throw Exception('Phiếu nhập không tồn tại');
      if ((receiptDoc['status'] as String? ?? 'draft') != 'draft') {
        throw Exception('Không thể xoá dòng hàng của phiếu đã xác nhận');
      }

      final currentQty = (receiptDoc['totalQty'] ?? 0) as int;
      final currentAmount = (receiptDoc['totalAmount'] ?? 0.0) as num;

      txn.delete(itemRef);
      txn.update(receiptRef, {
        'totalQty': (currentQty - qty).clamp(0, currentQty),
        'totalAmount':
            (currentAmount.toDouble() - lineTotal).clamp(0.0, double.infinity),
        'updatedAt': Timestamp.now(),
      });
    });
  }
}

