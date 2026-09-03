import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';

class CreateProviderDialog extends StatefulWidget {
  const CreateProviderDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreateProviderDialog(),
      ),
    );
  }

  @override
  State<CreateProviderDialog> createState() => _CreateProviderDialogState();
}

class _CreateProviderDialogState extends State<CreateProviderDialog> {
  static const List<String> _types = ['Repartidor', 'Vendedor'];
  static const List<String> _weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<Color> _defaultColors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF84CC16),
  ];

  final TextEditingController _nameController = TextEditingController();

  String _selectedType = _types.first;
  int _selectedWeekday = 0;
  Color _selectedColor = _defaultColors.first;
  bool _isNameInvalid = false;

  IconData get _selectedTypeIcon => _selectedType == 'Repartidor'
      ? Icons.local_shipping_outlined
      : Icons.storefront_outlined;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _isNameInvalid = true);
      return;
    }

    final created = context.read<ProvidersProvider>().addPerson(
          type: _selectedType,
          name: name,
          weekday: _selectedWeekday,
          colorValue: _selectedColor.value,
        );

    if (!created) {
      _showMessage('Ya existe un $_selectedType con ese nombre.');
      return;
    }

    // The dialog intentionally remains open so several people can be created
    // without having to reopen it after every entry.
    _nameController.clear();
    setState(() {
      _isNameInvalid = false;
      _selectedType = _types.first;
      _selectedWeekday = 0;
      _selectedColor = _defaultColors.first;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(initialColor: _selectedColor),
    );

    if (color != null && mounted) {
      setState(() => _selectedColor = color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Crear Vendedor/Repartidor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdown<String>(
                value: _selectedType,
                items: _types,
                icon: _selectedTypeIcon,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildNameField()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown<int>(
                      value: _selectedWeekday,
                      items: List<int>.generate(7, (index) => index),
                      itemLabel: (index) => _weekdays[index],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedWeekday = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Color',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ..._defaultColors.map(_buildColorOption),
                  InkWell(
                    onTap: _pickColor,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.inputBackground,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.buttonRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    'Crear ${_selectedType.toLowerCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    final borderColor = _isNameInvalid ? AppColors.dangerRed : AppColors.border;

    return TextField(
      controller: _nameController,
      onChanged: (_) {
        if (_isNameInvalid) setState(() => _isNameInvalid = false);
      },
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Nombre',
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        filled: true,
        fillColor: _isNameInvalid
            ? AppColors.dangerRed.withOpacity(0.06)
            : AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
    String Function(T value)? itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 19, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel?.call(item) ?? item.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildColorOption(Color color) {
    final selected = _selectedColor.value == color.value;

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: () => setState(() => _selectedColor = color),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  static const List<Color> _palette = [
    Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFFF43F5E),
    Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFFF59E0B),
    Color(0xFFEAB308), Color(0xFFCA8A04), Color(0xFF84CC16), Color(0xFF65A30D),
    Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF10B981), Color(0xFF059669),
    Color(0xFF14B8A6), Color(0xFF0D9488), Color(0xFF06B6D4), Color(0xFF0891B2),
    Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF3B82F6), Color(0xFF2563EB),
    Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF8B5CF6), Color(0xFF7C3AED),
    Color(0xFFA855F7), Color(0xFFC026D3), Color(0xFFEC4899), Color(0xFFDB2777),
    Color(0xFFF43F5E), Color(0xFF64748B), Color(0xFF475569), Color(0xFF334155),
    Color(0xFF1E293B), Color(0xFF111827), Color(0xFF000000), Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar color'),
      content: SizedBox(
        width: 360,
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: _palette.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final color = _palette[index];
            final selected = color.value == initialColor.value;

            return InkWell(
              onTap: () => Navigator.of(context).pop(color),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.textPrimary : AppColors.border,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        color: color.computeLuminance() > 0.55
                            ? AppColors.textPrimary
                            : Colors.white,
                        size: 17,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
