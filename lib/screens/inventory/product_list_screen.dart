import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../services/database_service.dart';
import 'add_product_screen.dart';
import 'stock_adjustment_list_screen.dart';
import '../purchase/purchase_list_screen.dart';
import '../supplier/supplier_list_screen.dart';
import '../category/category_list_screen.dart';
import '../customer/customer_list_screen.dart';
import '../sales/sale_list_screen.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  Future<void> _deleteProduct(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá sản phẩm'),
        content: Text(
            'Bạn có chắc muốn xoá sản phẩm "${product.name}" không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DatabaseService().deleteProduct(product.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi xoá sản phẩm: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kho Hàng Thông Minh"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.store, size: 40, color: Colors.white),
                  SizedBox(height: 8),
                  Text('SmartPOS ERP',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.blueAccent),
              title: const Text('Danh sách sản phẩm'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.category, color: Colors.blueAccent),
              title: const Text('Danh mục sản phẩm'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CategoryListScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.receipt_long, color: Colors.blueAccent),
              title: const Text('Nhập hàng'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PurchaseListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.business, color: Colors.blueAccent),
              title: const Text('Nhà cung cấp'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SupplierListScreen()),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.tune, color: Colors.blueAccent),
              title: const Text('Điều chỉnh tồn kho'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StockAdjustmentListScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.point_of_sale, color: Colors.blueAccent),
              title: const Text('Bán hàng'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SaleListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.blueAccent),
              title: const Text('Khách hàng'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerListScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có sản phẩm nào.\nNhấn + để thêm sản phẩm mới.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var product = Product.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.inventory, color: Colors.blue),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "SKU: ${product.sku} | Tồn kho: ${product.stock}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${product.price.toStringAsFixed(0)}đ",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        tooltip: 'Chỉnh sửa',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddProductScreen(product: product),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Xoá',
                        onPressed: () =>
                            _deleteProduct(context, product),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddProductScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

