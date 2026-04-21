/// Dòng hàng trong phiếu nhập
/// Firestore path: purchase_receipts/{receiptId}/items/{itemId}
/// TODO: Thêm lot/batch tracking, expiry date khi cần FIFO/FEFO
class PurchaseItem {
  final String id;
  final String productId;
  final String skuSnapshot;   // SKU tại thời điểm nhập (snapshot)
  final String nameSnapshot;  // Tên sản phẩm tại thời điểm nhập (snapshot)
  final int qty;
  final double importPrice;
  final double lineTotal;     // qty * importPrice

  const PurchaseItem({
    required this.id,
    required this.productId,
    required this.skuSnapshot,
    required this.nameSnapshot,
    required this.qty,
    required this.importPrice,
    required this.lineTotal,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> data, String id) {
    return PurchaseItem(
      id: id,
      productId: data['productId'] ?? '',
      skuSnapshot: data['skuSnapshot'] ?? '',
      nameSnapshot: data['nameSnapshot'] ?? '',
      qty: (data['qty'] ?? 0).toInt(),
      importPrice: (data['importPrice'] ?? 0).toDouble(),
      lineTotal: (data['lineTotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'skuSnapshot': skuSnapshot,
      'nameSnapshot': nameSnapshot,
      'qty': qty,
      'importPrice': importPrice,
      'lineTotal': lineTotal,
    };
  }
}
