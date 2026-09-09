import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/features/catalog/catalog.dart';
import 'package:stellar_pos/features/clients/clients.dart';
import 'package:stellar_pos/features/debts/debts.dart';
import 'package:stellar_pos/features/electronic_balance/electronic_balance.dart';
import 'package:stellar_pos/features/products/products.dart';
import 'package:stellar_pos/features/purchases/purchases.dart';
import 'package:stellar_pos/features/sales/sales.dart';
import 'package:stellar_pos/presentation/dashboard/main_dashboard_layout.dart';

class StellarPosApp extends StatelessWidget {
  const StellarPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.background,
        ),
        useMaterial3: true,
      ),
      home: const MainDashboardLayout(),
    );
  }
}

class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => ProvidersProvider()),
        ChangeNotifierProvider(create: (_) => PurchasesProvider()),
        ChangeNotifierProvider(create: (_) => ElectronicBalanceProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(
          create: (context) => DebtProvider(context.read<SalesProvider>()),
        ),
      ],
      child: child,
    );
  }
}
