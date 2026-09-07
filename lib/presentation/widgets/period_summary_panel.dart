import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class PeriodSummaryMetric {
  final String label;
  final String value;
  final Color? valueColor;

  const PeriodSummaryMetric(this.label, this.value, {this.valueColor});
}

class PeriodSummaryPanel extends StatelessWidget {
  final List<PeriodSummaryMetric> metrics;
  final String rangeLabel;

  const PeriodSummaryPanel({
    super.key,
    required this.metrics,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Resumen del período', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          ...metrics.asMap().entries.expand((entry) {
            final index = entry.key;
            final metric = entry.value;
            final children = <Widget>[
              _Metric(metric),
            ];
            if (index == 2 && metrics.length > 3) {
              children.add(const Divider(height: 22, color: AppColors.border));
            }
            return children;
          }),
          const Spacer(),
          Text(
            rangeLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final PeriodSummaryMetric metric;

  const _Metric(this.metric);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              metric.label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: metric.valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
