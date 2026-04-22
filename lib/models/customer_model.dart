import 'package:cloud_firestore/cloud_firestore.dart';

/// Khách hàng
/// Firestore path: customers/{customerId}
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int points;        // điểm tích luỹ
  final double totalSpent; // tổng tiền đã chi
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.points = 0,
    this.totalSpent = 0,
    required this.createdAt,
  });

  factory Customer.fromMap(Map<String, dynamic> data, String id) {
    return Customer(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      points: (data['points'] ?? 0).toInt(),
      totalSpent: (data['totalSpent'] ?? 0).toDouble(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      'points': points,
      'totalSpent': totalSpent,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
