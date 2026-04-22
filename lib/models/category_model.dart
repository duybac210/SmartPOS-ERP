/// Danh mục sản phẩm
/// Firestore path: categories/{categoryId}
class Category {
  final String id;
  final String name;
  final String? description;

  const Category({
    required this.id,
    required this.name,
    this.description,
  });

  factory Category.fromMap(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (description != null) 'description': description,
    };
  }
}
