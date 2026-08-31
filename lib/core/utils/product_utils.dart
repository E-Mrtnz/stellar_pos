class ProductUtils {
  const ProductUtils._();

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  static double asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  static String asString(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  static String name(Map<String, dynamic> product) {
    return asString(product['name']);
  }

  static String unit(Map<String, dynamic> product) {
    final unit = asString(product['unit']);

    if (unit.isNotEmpty) {
      return unit;
    }

    final name = asString(product['name']);

    final match = RegExp(
      r'(\d+(?:[.,]\d+)?\s*(?:ml|l|lt|litro|litros|g|gr|kg|lb|lbs|oz|unidad|unidades))\s*$',
      caseSensitive: false,
    ).firstMatch(name);

    return match?.group(1)?.trim() ?? '';
  }

  static String cleanName(Map<String, dynamic> product) {
    final name = asString(product['name']);

    if (name.isEmpty) {
      return '';
    }

    return name.replaceFirst(
      RegExp(
        r'\s+\d+(?:[.,]\d+)?\s*(?:ml|l|lt|litro|litros|g|gr|kg|lb|lbs|oz|unidad|unidades)\s*$',
        caseSensitive: false,
      ),
      '',
    );
  }

  static String department(Map<String, dynamic> product) {
    final department = asString(product['department']);

    if (department.isNotEmpty) {
      return department;
    }

    return asString(product['category']);
  }

  static int stock(Map<String, dynamic> product) {
    return asInt(product['stock']);
  }

  static int minStock(Map<String, dynamic> product) {
    return asInt(product['minStock'], fallback: 5);
  }

  static int maxStock(Map<String, dynamic> product) {
    return asInt(product['maxStock'], fallback: 40);
  }

  static double cost(Map<String, dynamic> product) {
    return asDouble(product['cost']);
  }

  static double price(Map<String, dynamic> product) {
    return asDouble(product['price']);
  }

  static double profit(Map<String, dynamic> product) {
    return price(product) - cost(product);
  }

  static double profitPercentage(Map<String, dynamic> product) {
    final productCost = cost(product);

    if (productCost <= 0) {
      return 0;
    }

    return (profit(product) / productCost) * 100;
  }

  static String money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}
