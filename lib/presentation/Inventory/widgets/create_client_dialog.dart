import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';

class CreateClientDialog extends StatefulWidget {
  const CreateClientDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreateClientDialog(),
      ),
    );
  }

  @override
  State<CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<CreateClientDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final Set<String> _invalidFields = <String>{};

  OverlayEntry? _validationOverlay;
  Timer? _validationTimer;

  bool _validate() {
    final invalidFields = <String>{};

    if (_nameController.text.trim().isEmpty) {
      invalidFields.add('name');
    }

    setState(() {
      _invalidFields
        ..clear()
        ..addAll(invalidFields);
    });

    if (invalidFields.isEmpty) {
      return true;
    }

    _showValidationAlert('El nombre del cliente es obligatorio.');
    return false;
  }

  void _clearError(String field) {
    if (!_invalidFields.contains(field)) {
      return;
    }

    setState(() => _invalidFields.remove(field));
  }

  void _createClient() {
    if (!_validate()) {
      return;
    }

    final client = Client(
      id: '',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    context.read<CatalogProvider>().addClient(client);

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
    _phoneController.dispose();
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
                        'Crear Cliente',
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
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Nombre del cliente',
                        isInvalid: _invalidFields.contains('name'),
                        onChanged: (_) => _clearError('name'),
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _phoneController,
                        hint: 'Número de teléfono',
                        keyboardType: TextInputType.phone,
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
                      onPressed: _createClient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                        ),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Crear Cliente'),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isInvalid = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final borderColor = isInvalid ? AppColors.dangerRed : AppColors.border;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: isInvalid ? AppColors.dangerRed.withOpacity(0.06) : AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor, width: isInvalid ? 1.8 : 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor, width: isInvalid ? 1.8 : 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isInvalid ? AppColors.dangerRed : AppColors.primary, width: 1.8),
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
