import 'package:cloud_firestore/cloud_firestore.dart';

/// Phiếu điều chỉnh tồn kho (kiểm kê / bù trừ chênh lệch)
/// Firestore path: stock_adjustments/{adjustmentId}
class StockAdjustment {
  final String id;
  final String productId;
  final String productNameSnapshot;
  final int delta;    // dương = nhập thêm, âm = giảm tồn
  final String reason;
  final String? note;
  final DateTime adjustedAt;

  const StockAdjustment({
    required this.id,
    required this.productId,
    required this.productNameSnapshot,
    required this.delta,
    required this.reason,
    this.note,
    required this.adjustedAt,
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> data, String id) {
    return StockAdjustment(
      id: id,
      productId: data['productId'] ?? '',
      productNameSnapshot: data['productNameSnapshot'] ?? '',
      delta: (data['delta'] ?? 0).toInt(),
      reason: data['reason'] ?? '',
      note: data['note'] as String?,
      adjustedAt:
          (data['adjustedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productNameSnapshot': productNameSnapshot,
      'delta': delta,
      'reason': reason,
      if (note != null) 'note': note,
      'adjustedAt': Timestamp.fromDate(adjustedAt),
    };
  }
}
