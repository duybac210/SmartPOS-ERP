import 'package:cloud_firestore/cloud_firestore.dart';

/// Nhà cung cấp
/// Firestore path: suppliers/{supplierId}
class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.createdAt,
  });

  factory Supplier.fromMap(Map<String, dynamic> data, String id) {
    return Supplier(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
