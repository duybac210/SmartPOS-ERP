import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái phiếu nhập
enum ReceiptStatus { draft, confirmed, cancelled }

extension ReceiptStatusX on ReceiptStatus {
  String get value {
    switch (this) {
      case ReceiptStatus.draft:
        return 'draft';
      case ReceiptStatus.confirmed:
        return 'confirmed';
      case ReceiptStatus.cancelled:
        return 'cancelled';
    }
  }

  static ReceiptStatus fromString(String s) {
    switch (s) {
      case 'confirmed':
        return ReceiptStatus.confirmed;
      case 'cancelled':
        return ReceiptStatus.cancelled;
      default:
        return ReceiptStatus.draft;
    }
  }
}

/// Phiếu nhập hàng (header)
/// Firestore path: purchase_receipts/{receiptId}
/// TODO: Thêm supplierId khi tích hợp quản lý nhà cung cấp
class PurchaseReceipt {
  final String id;
  final String code;          // PN-YYYYMMDD-HHMMSS
  final ReceiptStatus status; // draft | confirmed | cancelled
  final String? note;
  final int totalQty;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;

  const PurchaseReceipt({
    required this.id,
    required this.code,
    required this.status,
    this.note,
    required this.totalQty,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.confirmedAt,
  });

  factory PurchaseReceipt.fromMap(Map<String, dynamic> data, String id) {
    return PurchaseReceipt(
      id: id,
      code: data['code'] ?? '',
      status: ReceiptStatusX.fromString(data['status'] ?? 'draft'),
      note: data['note'] as String?,
      totalQty: (data['totalQty'] ?? 0).toInt(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'status': status.value,
      'note': note,
      'totalQty': totalQty,
      'totalAmount': totalAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
    };
  }
}
