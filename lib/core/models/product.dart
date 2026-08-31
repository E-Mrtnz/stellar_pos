class Product {
  final String id;
  final String name;
  final String unit;
  final String department;
  final double cost;
  final double price;
  final int stock;
  final int minStock;
  final int maxStock;
  final String category;
  final String barcode;

  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.department,
    required this.cost,
    required this.price,
    required this.stock,
    required this.minStock,
    required this.maxStock,
    required this.category,
    required this.barcode,
  });

  Product copyWith({
    String? id,
    String? name,
    String? unit,
    String? department,
    double? cost,
    double? price,
    int? stock,
    int? minStock,
    int? maxStock,
    String? category,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      department: department ?? this.department,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'department': department,
      'cost': cost,
      'price': price,
      'stock': stock,
      'minStock': minStock,
      'maxStock': maxStock,
      'category': category,
      'barcode': barcode,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      unit: map['unit']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      cost: _toDouble(map['cost']),
      price: _toDouble(map['price']),
      stock: _toInt(map['stock']),
      minStock: _toInt(map['minStock'], fallback: 5),
      maxStock: _toInt(map['maxStock'], fallback: 40),
      category: map['category']?.toString() ?? '',
      barcode: map['barcode']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
