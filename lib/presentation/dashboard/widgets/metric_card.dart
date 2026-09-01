import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class MetricCard extends StatelessWidget {
  final String amount;
  final String label;
  final Color color;
  final IconData? icon;
  final double iconRotation;
  final bool paymentArrow;

  const MetricCard({
    super.key,
    required this.amount,
    required this.label,
    required this.color,
    this.icon,
    this.iconRotation = 0,
    this.paymentArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: Transform.rotate(
                angle: iconRotation,
                child: paymentArrow
                    ? _buildPaymentArrowIcon()
                    : Icon(
                        icon,
                        size: 20,
                        color: color,
                      ),
              ),
            ),
            const SizedBox(height: 2),
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
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppSizes.textMedium,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentArrowIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.payment_outlined,
          size: 20,
          color: color,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
