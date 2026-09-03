import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/provider_person.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';

class CreateProviderDialog extends StatefulWidget {
  final ProviderRoute? route;

  const CreateProviderDialog({super.key, this.route});

  static Future<void> show(
    BuildContext context, {
    ProviderRoute? route,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreateProviderDialog(route: route),
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
  ];

  static final List<Color> _recentColors = [];

  String? _selectedType;
  String? _selectedDistributor;
  final Set<int> _selectedWeekdays = {};
  Color _selectedColor = _defaultColors.first;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    _selectedType = route?.type;
    _selectedDistributor = route?.distributorName;
    if (route != null) {
      _selectedWeekdays.addAll(route.weekdays);
      _selectedColor = Color(route.colorValue);
    }
  }

  String get _weekdayLabel {
    if (_selectedType == 'Repartidor') return 'Días de entrega';
    return 'Días de visita';
  }

  String get _weekdayValidationMessage {
    if (_selectedType == 'Repartidor') {
      return 'Selecciona al menos un día de entrega.';
    }
    return 'Selecciona al menos un día de visita.';
  }

  IconData? get _selectedTypeIcon {
    if (_selectedType == 'Repartidor') return Icons.local_shipping_outlined;
    if (_selectedType == 'Vendedor') return Icons.storefront_outlined;
    return null;
  }

  Future<void> _pickColor() async {
    var pickerColor = _selectedColor;

    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: false,
            pickerAreaHeightPercent: 0.75,
            hexInputBar: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(pickerColor),
            child: const Text('Seleccionar'),
          ),
        ],
      ),
    );

    if (color != null && mounted) {
      _rememberRecentColor(color);
      setState(() => _selectedColor = color);
    }
  }

  void _rememberRecentColor(Color color) {
    _recentColors.removeWhere((item) => item.value == color.value);
    _recentColors.insert(0, color);
    if (_recentColors.length > 8) _recentColors.removeLast();
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_selectedWeekdays.contains(weekday)) {
        _selectedWeekdays.remove(weekday);
      } else {
        _selectedWeekdays.add(weekday);
      }
    });
  }

  void _save() {
    final provider = context.read<ProvidersProvider>();
    final isEditing = widget.route != null;

    if (_selectedType == null || _selectedDistributor == null) {
      _showMessage('Selecciona el tipo y la distribuidora.');
      return;
    }

    if (_selectedWeekdays.isEmpty) {
      _showMessage(_weekdayValidationMessage);
      return;
    }

    final success = isEditing
        ? provider.updateRoute(
            id: widget.route!.id,
            type: _selectedType!,
            distributorName: _selectedDistributor!,
            weekdays: _selectedWeekdays.toList(),
            colorValue: _selectedColor.value,
          )
        : provider.addRoute(
            type: _selectedType!,
            distributorName: _selectedDistributor!,
            weekdays: _selectedWeekdays.toList(),
            colorValue: _selectedColor.value,
          );

    if (!success) {
      _showMessage(
        isEditing
            ? 'No se pudo actualizar la ruta. Revisa si ya existe otra ruta para esa distribuidora y tipo.'
            : 'No se pudo asignar la ruta.',
      );
      return;
    }

    _resetForm();
  }

  void _resetForm() {
    setState(() {
      _selectedType = null;
      _selectedDistributor = null;
      _selectedWeekdays.clear();
      _selectedColor = _defaultColors.first;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distributors = context.watch<ProvidersProvider>().distributors;
    final selectedDistributor = distributors.contains(_selectedDistributor)
        ? _selectedDistributor
        : null;
    final isEditing = widget.route != null;
    final hasDistributors = distributors.isNotEmpty;

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
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Editar ruta de Proveedor'
                          : 'Asignar ruta de Proveedor',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdown<String>(
                value: _selectedType,
                items: _types,
                icon: _selectedTypeIcon,
                hint: 'Tipo de ruta',
                onChanged: (value) => setState(() {
                  _selectedType = value;
                }),
              ),
              const SizedBox(height: 10),
              _buildDropdown<String>(
                value: selectedDistributor,
                items: distributors,
                hint: hasDistributors
                    ? 'Distribuidora'
                    : 'Crea una distribuidora primero',
                onChanged: hasDistributors
                    ? (value) =>
                        setState(() => _selectedDistributor = value)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                _weekdayLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List<Widget>.generate(7, (index) {
                  final selected = _selectedWeekdays.contains(index);
                  return ChoiceChip(
                    label: Text(_weekdays[index]),
                    selected: selected,
                    onSelected: (_) => _toggleWeekday(index),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.inputBackground,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text(
                'Color',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 7,
                runSpacing: 7,
                children: [
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
              if (_recentColors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Colores usados recientemente',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _recentColors.map(_buildColorOption).toList(),
                ),
              ],
              if (!hasDistributors) ...[
                const SizedBox(height: 10),
                const Text(
                  'Primero crea al menos una distribuidora con el botón inferior.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Guardar cambios' : 'Asignar ruta',
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

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?>? onChanged,
    String Function(T value)? itemLabel,
    IconData? icon,
    String? hint,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 19, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

    return InkWell(
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
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.55
                    ? AppColors.textPrimary
                    : Colors.white,
                size: 16,
              )
            : null,
      ),
    );
  }
}
