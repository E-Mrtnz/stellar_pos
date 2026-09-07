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
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.pagePadding,
            AppDimensions.pagePadding,
            AppDimensions.pagePadding,
            0,
          ),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compras', style: AppTextStyles.brandTitle),
                SizedBox(height: 3),
                Text(
                  'Historial y registro de las compras realizadas.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const Expanded(child: legacy.PurchasesLayout()),
      ],
    );
  }
}
