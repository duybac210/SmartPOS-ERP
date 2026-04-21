class Product {
  final String id;
  final String name;
  final String sku;
  final double price;
  final int stock;

  Product({required this.id, required this.name, required this.sku, required this.price, required this.stock});

  // Chuyển dữ liệu từ Firebase thành đối tượng Product
  factory Product.fromMap(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      sku: data['sku'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      stock: (data['stock'] ?? 0).toInt(),
    );
  }
}