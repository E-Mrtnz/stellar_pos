import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class SidebarDrawer extends StatelessWidget {
  final bool isExpanded;
  final int selectedIndex;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onItemSelected;

  const SidebarDrawer({
    super.key,
    required this.isExpanded,
    required this.selectedIndex,
    required this.onToggleExpand,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isExpanded ? 220 : 72,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    if (isExpanded) ...[
                      const SizedBox(width: 12),
                      const Text(
                        AppStrings.appName,
                        style: AppTextStyles.brandTitle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSidebarItem(0, Icons.home_rounded, AppStrings.navHome),
                    _buildSidebarItem(
                      1,
                      Icons.inventory_2_rounded,
                      AppStrings.navInventory,
                    ),
                    _buildSidebarItem(
                      2,
                      Icons.sim_card_outlined,
                      AppStrings.navElectronicBalance,
                    ),
                    _buildSidebarItem(
                      3,
                      Icons.bar_chart_rounded,
                      AppStrings.navStats,
                    ),
                    _buildSidebarItem(
                      4,
                      Icons.shopping_bag_rounded,
                      AppStrings.navPurchases,
                    ),
                    _buildSidebarItem(
                      5,
                      Icons.local_shipping_outlined,
                      AppStrings.navProviders,
                    ),
                  ],
                ),
              ),
              const Divider(
                indent: 16,
                endIndent: 16,
                height: 1,
                color: AppColors.border,
              ),
              const SizedBox(height: 10),
              _buildSidebarItem(
                6,
                Icons.settings_rounded,
                AppStrings.navSettings,
              ),
              const SizedBox(height: 16),
            ],
          ),
          Positioned(
            top: 20,
            right: 8,
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  isExpanded
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;

    return InkWell(
      onTap: () => onItemSelected(index),
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 22,
            ),
            if (isExpanded) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.sidebarItem.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            if (isSelected)
              Container(
                width: 4,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
