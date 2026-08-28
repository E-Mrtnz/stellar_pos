import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/views/web/main_dashboard_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StellarPosApp());
}

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
          surface:
              AppColors.background, // En lugar del antiguo 'background'
        ),
        useMaterial3: true,
      ),
      home: const MainDashboardLayout(),
    );
  }
}
