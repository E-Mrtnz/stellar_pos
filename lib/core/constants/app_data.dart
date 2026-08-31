import 'package:stellar_pos/core/constants/app_constants.dart';

class AppData {
  static const List<String> debtors = [
    'Juan Pérez',
    'María López',
    'Carlos Gómez',
    'Ana Martínez',
  ];

  static const List<String> productTags = [
    'Sodas',
    'Jugos',
    'Sopas Instantáneas',
    'Snacks',
  ];

  static const List<String> departments = [
    'Coca-Cola',
    'Pepsi',
    'Maggi',
    'Sabritas',
  ];

  static const List<Map<String, dynamic>> products = [
    {
      'id': '1',
      'name': 'Coca Cola',
      'unit': '354ml',
      'department': 'Coca-Cola',
      'cost': 0.63,
      'price': 0.80,
      'stock': 24,
      'minStock': 5,
      'maxStock': 40,
      'category': 'Bebidas',
    },
    {
      'id': '2',
      'name': 'Papas Lays',
      'unit': '45g',
      'department': 'Sabritas',
      'cost': 0.45,
      'price': 0.65,
      'stock': 15,
      'minStock': 5,
      'maxStock': 40,
      'category': 'Snacks',
    },
    {
      'id': '3',
      'name': 'Arroz San Pedro',
      'unit': '1lb',
      'department': 'San Pedro',
      'cost': 0.55,
      'price': 0.75,
      'stock': 40,
      'minStock': 5,
      'maxStock': 50,
      'category': 'Abarrotes',
    },
    {
      'id': '4',
      'name': 'Leche Salud',
      'unit': '1L',
      'department': 'Salud',
      'cost': 1.10,
      'price': 1.35,
      'stock': 8,
      'minStock': 5,
      'maxStock': 30,
      'category': 'Lácteos',
    },
    {
      'id': '5',
      'name': 'Jabón Axion',
      'unit': '250g',
      'department': 'Axion',
      'cost': 0.65,
      'price': 0.90,
      'stock': 12,
      'minStock': 5,
      'maxStock': 30,
      'category': 'Limpieza',
    },
    {
      'id': '6',
      'name': 'Shampoo Savilé',
      'unit': '750ml',
      'department': 'Savilé',
      'cost': 2.80,
      'price': 3.50,
      'stock': 6,
      'minStock': 5,
      'maxStock': 20,
      'category': 'Cuidado Personal',
    },
  ];

  static const List<Map<String, dynamic>> paymentMethods = [
    {
      'index': AppPaymentMethods.cash,
      'icon': 'cash',
      'label': AppStrings.cashPayment,
    },
    {
      'index': AppPaymentMethods.card,
      'icon': 'card',
      'label': AppStrings.cardPayment,
    },
    {
      'index': AppPaymentMethods.transfer,
      'icon': 'transfer',
      'label': AppStrings.transferPayment,
    },
    {
      'index': AppPaymentMethods.credit,
      'icon': 'credit',
      'label': AppStrings.creditPayment,
    },
  ];
}
