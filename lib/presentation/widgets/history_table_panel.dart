import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class HistoryTablePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final int itemCount;
  final Widget header;
  final IndexedWidgetBuilder itemBuilder;
  final Widget emptyState;

  const HistoryTablePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.itemCount,
    required this.header,
    required this.itemBuilder,
    required this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 7),
                Text(title, style: AppTextStyles.sectionTitle),
                const Spacer(),
                Text(
                  '$itemCount',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          header,
          Expanded(
            child: itemCount == 0
                ? emptyState
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: itemCount,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: itemBuilder,
                  ),
          ),
        ],
      ),
    );
  }
}
