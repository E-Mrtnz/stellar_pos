import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class MetricCard extends StatelessWidget {
  final String amount;
  final String label;
  final Color color;

  const MetricCard({
    super.key,
    required this.amount,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            amount,
            style: TextStyle(
              fontSize: AppSizes.textLarge,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppSizes.textMedium,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
