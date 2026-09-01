import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class MetricCard extends StatelessWidget {
  final String amount;
  final String label;
  final Color color;
  final IconData? icon;
  final double iconRotation;

  const MetricCard({
    super.key,
    required this.amount,
    required this.label,
    required this.color,
    this.icon,
    this.iconRotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 106,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.72),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: iconRotation,
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppSizes.textLarge,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppSizes.textMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
