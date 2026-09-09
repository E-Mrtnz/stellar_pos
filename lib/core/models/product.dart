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
        cost: _double(map['cost']),
        price: _double(map['price']),
        stock: _int(map['stock']),
        minStock: _int(map['minStock'], fallback: 5),
        maxStock: _int(map['maxStock'], fallback: 40),
        category: map['category']?.toString() ?? '',
        barcode: map['barcode']?.toString() ?? '',
        imageData: map['imageData']?.toString() ?? '',
        hasGroupPricing: _bool(map['hasGroupPricing']),
        groupQuantity: _int(map['groupQuantity']),
        groupPrice: _double(map['groupPrice']),
        metadata: map['metadata'] is Map
            ? SyncMetadata.fromMap(Map<String, dynamic>.from(map['metadata']))
            : SyncMetadata.initial(),
      );

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;

  static int _int(dynamic value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí';
  }
}
