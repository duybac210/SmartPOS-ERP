/// Dòng hàng trong đơn bán
/// Firestore path: sale_orders/{orderId}/items/{itemId}
class SaleItem {
  final String id;
  final String productId;
  final String nameSnapshot;
  final double priceSnapshot; // giá bán tại thời điểm bán
  final int qty;
  final double lineTotal; // qty * priceSnapshot

  const SaleItem({
    required this.id,
    required this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.qty,
    required this.lineTotal,
  });

  factory SaleItem.fromMap(Map<String, dynamic> data, String id) {
    return SaleItem(
      id: id,
      productId: data['productId'] ?? '',
      nameSnapshot: data['nameSnapshot'] ?? '',
      priceSnapshot: (data['priceSnapshot'] ?? 0).toDouble(),
      qty: (data['qty'] ?? 0).toInt(),
      lineTotal: (data['lineTotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'nameSnapshot': nameSnapshot,
      'priceSnapshot': priceSnapshot,
      'qty': qty,
      'lineTotal': lineTotal,
    };
  }
}
