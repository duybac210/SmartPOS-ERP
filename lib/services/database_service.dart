import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference productCollection = FirebaseFirestore.instance
      .collection('products');

  Future addProduct(String name, String sku, double price, int stock) async {
    return await productCollection.add({
      'name': name,
      'sku': sku,
      'price': price,
      'stock': stock,
    });
  }
}
