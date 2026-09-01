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
      width: 100,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: Transform.rotate(
                angle: iconRotation,
                child: paymentArrow
                    ? _buildPaymentArrowIcon()
                    : Icon(
                        icon,
                        size: 18,
                        color: color,
                      ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    amount,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.textLarge,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppSizes.textMedium,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
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
          size: 18,
          color: color,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 11,
            color: color,
          ),
        ),
      ],
    );
  }
}
