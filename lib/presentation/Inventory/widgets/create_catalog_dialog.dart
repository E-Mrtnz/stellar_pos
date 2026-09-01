import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';

class CreateCatalogDialog extends StatefulWidget {
  const CreateCatalogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreateCatalogDialog(),
      ),
    );
  }

  @override
  State<CreateCatalogDialog> createState() => _CreateCatalogDialogState();
}

class _CreateCatalogDialogState extends State<CreateCatalogDialog> {
  static const List<String> _types = ['Etiqueta', 'Departamento'];

  String _selectedType = _types.first;

  final TextEditingController _nameController = TextEditingController();

  bool _nameInvalid = false;

  OverlayEntry? _validationOverlay;
  Timer? _validationTimer;

  void _createCatalogItem() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _nameInvalid = true;
      });

      _showValidationAlert('El nombre es obligatorio.');

      return;
    }

    final provider = context.read<CatalogProvider>();

    if (_selectedType == 'Etiqueta') {
      provider.addTag(name);
    } else {
      provider.addDepartment(name);
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _showValidationAlert(String message) {
    _validationTimer?.cancel();
    _validationOverlay?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 18,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: _ValidationAlert(message: message),
            ),
          ),
        );
      },
    );

    _validationOverlay = entry;
    overlay.insert(entry);

    _validationTimer = Timer(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
      }

      if (identical(_validationOverlay, entry)) {
        _validationOverlay = null;
      }
    });
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _validationOverlay?.remove();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Crear Etiqueta / Departamento',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(15),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, color: AppColors.textSecondary, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        isDense: true,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Tipo',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        items: _types.map((type) => DropdownMenuItem<String>(value: type, child: Text(type))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedType = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        onChanged: (_) {
                          if (!_nameInvalid) return;
                          setState(() => _nameInvalid = false);
                        },
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Nombre de etiqueta/departamento',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: _nameInvalid ? AppColors.dangerRed.withOpacity(0.06) : AppColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _nameInvalid ? AppColors.dangerRed : AppColors.border, width: _nameInvalid ? 1.8 : 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _nameInvalid ? AppColors.dangerRed : AppColors.border, width: _nameInvalid ? 1.8 : 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _nameInvalid ? AppColors.dangerRed : AppColors.primary, width: 1.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _createCatalogItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                        ),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Crear Etiqueta / Departamento'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValidationAlert extends StatelessWidget {
  final String message;

  const _ValidationAlert({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.warningOrange,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Campo requerido', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(message, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
