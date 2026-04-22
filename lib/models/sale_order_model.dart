import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái đơn bán hàng
enum SaleStatus { draft, paid, cancelled }

extension SaleStatusX on SaleStatus {
  String get value {
    switch (this) {
      case SaleStatus.draft:
        return 'draft';
      case SaleStatus.paid:
        return 'paid';
      case SaleStatus.cancelled:
        return 'cancelled';
    }
  }

  static SaleStatus fromString(String s) {
    switch (s) {
      case 'paid':
        return SaleStatus.paid;
      case 'cancelled':
        return SaleStatus.cancelled;
      default:
        return SaleStatus.draft;
    }
  }
}

/// Phương thức thanh toán
enum PaymentMethod { cash, transfer, card }

extension PaymentMethodX on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.transfer:
        return 'transfer';
      case PaymentMethod.card:
        return 'card';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tiền mặt';
      case PaymentMethod.transfer:
        return 'Chuyển khoản';
      case PaymentMethod.card:
        return 'Thẻ';
    }
  }

  static PaymentMethod fromString(String s) {
    switch (s) {
      case 'transfer':
        return PaymentMethod.transfer;
      case 'card':
        return PaymentMethod.card;
      default:
        return PaymentMethod.cash;
    }
  }
}

/// Đơn bán hàng (header)
/// Firestore path: sale_orders/{orderId}
class SaleOrder {
  final String id;
  final String code;               // HD-YYYYMMDD-HHMMSS
  final SaleStatus status;
  final String? customerId;
  final String? customerName;
  final int totalQty;
  final double totalAmount;
  final double discount;           // số tiền chiết khấu
  final double finalAmount;        // totalAmount - discount
  final PaymentMethod paymentMethod;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;

  const SaleOrder({
    required this.id,
    required this.code,
    required this.status,
    this.customerId,
    this.customerName,
    required this.totalQty,
    required this.totalAmount,
    this.discount = 0,
    required this.finalAmount,
    this.paymentMethod = PaymentMethod.cash,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
  });

  factory SaleOrder.fromMap(Map<String, dynamic> data, String id) {
    return SaleOrder(
      id: id,
      code: data['code'] ?? '',
      status: SaleStatusX.fromString(data['status'] ?? 'draft'),
      customerId: data['customerId'] as String?,
      customerName: data['customerName'] as String?,
      totalQty: (data['totalQty'] ?? 0).toInt(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      finalAmount: (data['finalAmount'] ?? 0).toDouble(),
      paymentMethod:
          PaymentMethodX.fromString(data['paymentMethod'] ?? 'cash'),
      note: data['note'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'status': status.value,
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      'totalQty': totalQty,
      'totalAmount': totalAmount,
      'discount': discount,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod.value,
      if (note != null) 'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
    };
  }
}
