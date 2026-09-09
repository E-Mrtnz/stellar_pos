import 'package:stellar_pos/core/models/sync_metadata.dart';

class Product implements SyncableEntity {
  @override
  final String id;
  final String name;
  final String unit;
  final String department;
  final String brand;
  final double cost;
  final double price;
  final int stock;
  final int minStock;
  final int maxStock;
  final String category;
  final String barcode;
  final String imageData;
  final bool hasGroupPricing;
  final int groupQuantity;
  final double groupPrice;
  @override
  final SyncMetadata metadata;

  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.department,
    this.brand = '',
    required this.cost,
    required this.price,
    required this.stock,
    required this.minStock,
    required this.maxStock,
    required this.category,
    required this.barcode,
    this.imageData = '',
    this.hasGroupPricing = false,
    this.groupQuantity = 0,
    this.groupPrice = 0,
    SyncMetadata? metadata,
  }) : metadata = metadata ?? SyncMetadata.initial();

  double priceForQuantity(int quantity) {
    if (quantity <= 0) return 0;
    if (!hasGroupPricing || groupQuantity <= 0 || groupPrice < 0) {
      return price * quantity;
    }
    final groups = quantity ~/ groupQuantity;
    final remaining = quantity % groupQuantity;
    return groups * groupPrice + remaining * price;
  }

  Product copyWith({
    String? id,
    String? name,
    String? unit,
    String? department,
    String? brand,
    double? cost,
    double? price,
    int? stock,
    int? minStock,
    int? maxStock,
    String? category,
    String? barcode,
    String? imageData,
    bool? hasGroupPricing,
    int? groupQuantity,
    double? groupPrice,
    SyncMetadata? metadata,
    bool touchMetadata = true,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      department: department ?? this.department,
      brand: brand ?? this.brand,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      imageData: imageData ?? this.imageData,
      hasGroupPricing: hasGroupPricing ?? this.hasGroupPricing,
      groupQuantity: groupQuantity ?? this.groupQuantity,
      groupPrice: groupPrice ?? this.groupPrice,
      metadata: metadata ?? (touchMetadata ? this.metadata.touch() : this.metadata),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'unit': unit,
        'department': department,
        'brand': brand,
        'cost': cost,
        'price': price,
        'stock': stock,
        'minStock': minStock,
        'maxStock': maxStock,
        'category': category,
        'barcode': barcode,
        'imageData': imageData,
        'hasGroupPricing': hasGroupPricing,
        'groupQuantity': groupQuantity,
        'groupPrice': groupPrice,
        'metadata': metadata.toMap(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        unit: map['unit']?.toString() ?? '',
        department: map['department']?.toString() ?? '',
        brand: map['brand']?.toString() ?? '',
        cost: _toDouble(map['cost']),
        price: _toDouble(map['price']),
        stock: _toInt(map['stock']),
        minStock: _toInt(map['minStock'], fallback: 5),
        maxStock: _toInt(map['maxStock'], fallback: 40),
        category: map['category']?.toString() ?? '',
        barcode: map['barcode']?.toString() ?? '',
        imageData: map['imageData']?.toString() ?? '',
        hasGroupPricing: _toBool(map['hasGroupPricing']),
        groupQuantity: _toInt(map['groupQuantity']),
        groupPrice: _toDouble(map['groupPrice']),
        metadata: _metadata(map['metadata']),
      );

  static SyncMetadata _metadata(dynamic value) => value is Map
      ? SyncMetadata.fromMap(Map<String, dynamic>.from(value))
      : SyncMetadata.initial();

  static double _toDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0.0;

  static int _toInt(dynamic value, {int fallback = 0}) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí';
  }
}
