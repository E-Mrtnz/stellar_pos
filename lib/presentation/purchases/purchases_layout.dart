import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'purchases_layout_legacy.dart' as legacy;

class PurchasesLayout extends StatelessWidget {
  const PurchasesLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.pagePadding, AppDimensions.pagePadding, AppDimensions.pagePadding, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compras', style: AppTextStyles.brandTitle),
                    SizedBox(height: 3),
                    Text('Historial y registro de las compras realizadas.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.searchFieldRadius), border: Border.all(color: AppColors.border)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_bag_outlined, size: 17, color: AppColors.textSecondary), SizedBox(width: 8), Text('Registro de compras', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))]),
              ),
            ],
          ),
        ),
        const Expanded(child: legacy.PurchasesLayout()),
      ],
    );
  }
}
