import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF3F4F8);
  static const Color cardBackground = Colors.white;
  static const Color primary = Color(0xFF4F46E5);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color inputBackground = Color(0xFFF8FAFC);
  static const Color chipBackground = Color(0xFFF1F5F9);
  static const Color textDarkSecondary = Color(0xFF475569);
  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color activeNavBackground = Color(0xFFE8ECEF);
  static const Color sidebarBackground = Colors.white;
  static const Color shadowColor = Color(0x0D000000);
  static const Color overlayBackground = Color(0x80000000);
  static const Color cardExtensionBackground = Color(0xFF3B82F6);
}

class AppDimensions {
  static const double pagePadding = 12.0;
  static const double cardRadius = 12.0;
  static const double largeCardRadius = 16.0;
  static const double dialogRadius = 20.0;
  static const double sidebarExpandedWidth = 220.0;
  static const double sidebarCollapsedWidth = 72.0;
  static const double productGridSpacing = 12.0;
  static const double categorySpacing = 8.0;
  static const double searchFieldRadius = 10.0;
  static const double buttonRadius = 8.0;
  static const double productCardAspectRatio = 0.82;
  static const double productImageSize = 36.0;
  static const double stockBadgeHeight = 26.0;
  static const double inventoryImageSize = 40.0;
  static const double shadowBlur = 10.0;
  static const double shadowOffsetY = 4.0;
  static const double sidebarAnimationDuration = 250.0;
  static const double fastAnimationDuration = 150.0;
  static const double inventoryFabElevation = 4.0;
}

class AppSizes {
  static const double iconSmall = 14.0;
  static const double iconMedium = 18.0;
  static const double iconLarge = 24.0;
  static const double textSmall = 10.0;
  static const double textMedium = 11.0;
  static const double textNormal = 12.0;
  static const double textLarge = 14.0;
}

class AppTextStyles {
  static const TextStyle brandTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static const TextStyle searchHint = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
  );
  static const TextStyle sidebarItem = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle chipText = TextStyle(fontSize: 13);
  static const TextStyle ticketLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static const TextStyle ticketValue = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static const TextStyle totalLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static const TextStyle totalValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.successGreen,
  );
  static const TextStyle changeValue = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppColors.dangerRed,
  );
  static const TextStyle productName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle productMetadata = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );
  static const TextStyle productPrice = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );
  static const TextStyle inventoryHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}

class AppStrings {
  static const String appName = 'Stellar POS';
  static const String navHome = 'Inicio';
  static const String navInventory = 'Inventario';
  static const String navStats = 'Estadísticas';
  static const String navPurchases = 'Compras';
  static const String navProviders = 'Proveedores';
  static const String navSettings = 'Ajustes';
  static const String searchPlaceholder = 'Buscar producto...';
  static const String salesSummaryTitle = 'Resumen Ventas';
  static const String ticketNumberLabel = 'Nº Factura:';
  static const String emptyCartMessage = 'No hay productos seleccionados';
  static const String createSaleButton = 'Crear Venta';
  static const String paymentDetailsTitle = 'Detalles de Pago';
  static const String clearCartButton = 'Borrar todo';
  static const String subtotalLabel = 'Subtotal';
  static const String discountLabel = 'Descuento';
  static const String cardFeeLabel = 'Cargo tarjeta';
  static const String cashReceivedLabel = 'Recibido';
  static const String changeLabel = 'Cambio';
  static const String totalLabel = 'Total';
  static const String cashPayment = 'Efectivo';
  static const String cardPayment = 'Tarjeta';
  static const String transferPayment = 'Transferencia';
  static const String creditPayment = 'Fiado';
  static const String inventoryEmptyMessage = 'No hay productos en esta categoría';
  static const String inventoryProductHeader = 'Producto';
  static const String inventoryCostHeader = 'Costo';
  static const String inventorySalePriceHeader = 'P. Venta';
  static const String inventoryStockHeader = 'Cant. disponible';
  static const String inventoryProfitHeader = 'Ganancia';
  static const String inventoryMarginHeader = '%';
  static const String totalInvestment = 'Inversión total';
  static const String totalSales = 'Venta total';
  static const String totalProfit = 'Ganancia total';
  static const String createProductTitle = 'Crear Producto';
  static const String productNameHint = 'Nombre de producto';
  static const String unitHint = 'Medida / Unidad';
  static const String purchasePriceHint = 'Precio de compra';
  static const String salePriceHint = 'Precio de venta';
  static const String barcodeHint = 'Código de barras';
  static const String selectTagHint = 'Etiqueta';
  static const String selectDeptHint = 'Distribuidora';
  static const String saveButton = 'Guardar';
  static const String createTagsTooltip = 'Crear etiquetas';
  static const String createClientsTooltip = 'Crear Clientes';
  static const String createProductsTooltip = 'Crear Productos';
}

class AppCategories {
  static const List<String> all = [
    'Todos',
    'Bebidas',
    'Snacks',
    'Abarrotes',
    'Lácteos',
    'Limpieza',
    'Cuidado Personal',
  ];
}

class AppNavigation {
  static const int home = 0;
  static const int inventory = 1;
  static const int stats = 2;
  static const int purchases = 3;
  static const int providers = 4;
  static const int settings = 5;
}

class AppPaymentMethods {
  static const int cash = 0;
  static const int card = 1;
  static const int transfer = 2;
  static const int credit = 3;
}

class AppInventory {
  static const int defaultMinStock = 5;
  static const int defaultMaxStock = 40;
  static const int warningMultiplier = 2;
  static const double cardFeePercentage = 0.05;
}
