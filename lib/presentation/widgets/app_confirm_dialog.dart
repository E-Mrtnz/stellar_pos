import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class AppConfirmDialog {
  static Future<bool> update(
    BuildContext context, {
    String itemName = 'este ítem',
  }) {
    return _show(
      context,
      title: 'Confirmar actualización',
      message: '¿Está seguro que desea actualizar $itemName?',
      confirmLabel: 'Actualizar',
    );
  }

  static Future<bool> delete(
    BuildContext context, {
    String itemName = 'este ítem',
  }) {
    return _show(
      context,
      title: 'Confirmar eliminación',
      message: '¿Está seguro que desea eliminar $itemName?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
  }

  static Future<bool> _show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 390,
            padding: const EdgeInsets.all(22),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: destructive
                            ? AppColors.dangerRed.withAlpha(18)
                            : AppColors.primary.withAlpha(18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        destructive
                            ? Icons.delete_outline_rounded
                            : Icons.edit_outlined,
                        color: destructive
                            ? AppColors.dangerRed
                            : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: destructive
                            ? AppColors.dangerRed
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }
}
