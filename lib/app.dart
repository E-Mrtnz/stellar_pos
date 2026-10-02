import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/dashboard/main_dashboard_layout.dart';

/// Root application widget.
///
/// Cloud authentication and synchronization are intentionally disconnected
/// while the new cloud architecture is designed from scratch.
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
