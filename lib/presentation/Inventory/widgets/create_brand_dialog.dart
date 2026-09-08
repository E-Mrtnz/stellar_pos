import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';

class CreateBrandDialog extends StatefulWidget {
  const CreateBrandDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreateBrandDialog(),
      ),
    );
  }

  @override
  State<CreateBrandDialog> createState() => _CreateBrandDialogState();
}

class _CreateBrandDialogState extends State<CreateBrandDialog> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    context.read<CatalogProvider>().addBrand(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(child: Text('Crear marca', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _add(),
              onChanged: (_) { if (_invalid) setState(() => _invalid = false); },
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Nombre de la marca',
                filled: true,
                fillColor: _invalid ? AppColors.dangerRed.withOpacity(0.06) : AppColors.inputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _invalid ? AppColors.dangerRed : AppColors.border)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _add, child: const Text('Crear marca'))),
          ],
        ),
      ),
    );
  }
}
