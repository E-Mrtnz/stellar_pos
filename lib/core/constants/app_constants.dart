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

  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);

  static const Color sidebarBackground = Colors.white;
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

  // Tipografías más compactas para maximizar espacio vertical
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
}

class AppStrings {
  static const String appName = 'Stellar POS';
  static const String navHome = 'Inicio';
  static const String navInventory = 'Inventario';
  static const String navStats = 'Estadísticas';
  static const String navPurchases = 'Compras';
  static const String navSettings = 'Ajustes';

  static const String searchPlaceholder = 'Buscar producto...';
  static const String salesSummaryTitle = 'Resumen Ventas';
  static const String ticketNumberLabel = 'Nº Factura:';
  static const String emptyCartMessage =
      'No hay productos seleccionados';
  static const String selectedViewPrefix = 'Vista seleccionada: ';
  static const String createSaleButton = 'Crear Venta';
}
