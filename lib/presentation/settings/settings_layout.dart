import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/settings/printer_settings_layout.dart';

/// Main settings workspace.
///
/// The left side contains the available settings sections and the right side
/// renders the selected section. New settings can be added to [_sections]
/// without changing the surrounding layout.
class SettingsLayout extends StatefulWidget {
  const SettingsLayout({super.key});

  @override
  State<SettingsLayout> createState() => _SettingsLayoutState();
}

class _SettingsSection {
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.builder,
  });
}

class _SettingsLayoutState extends State<SettingsLayout> {
  int _selectedIndex = 0;

  late final List<_SettingsSection> _sections = [
    _SettingsSection(
      title: 'Impresoras',
      icon: Icons.print_outlined,
      builder: (_) => const PrinterSettingsLayout(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedSection = _sections[_selectedIndex];

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSettingsMenu(),
          const SizedBox(width: AppDimensions.productGridSpacing),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: selectedSection.builder(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu() {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Text(
              'Ajustes',
              style: AppTextStyles.sectionTitle,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          ...List.generate(
            _sections.length,
            (index) => _buildSettingsItem(index, _sections[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(int index, _SettingsSection section) {
    final selected = index == _selectedIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primary.withAlpha(18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 19,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
