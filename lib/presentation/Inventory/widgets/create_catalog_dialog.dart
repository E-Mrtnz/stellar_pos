import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';

class CreateCatalogDialog extends StatefulWidget {
  const CreateCatalogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
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
  final TextEditingController _nameController = TextEditingController();

  bool _nameInvalid = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createTag() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameInvalid = true);
      return;
    }

    context.read<CatalogProvider>().addTag(name);
    _nameController.clear();
    setState(() => _nameInvalid = false);
  }

  @override
  Widget build(BuildContext context) {
    final tags = context.watch<CatalogProvider>().tags;

    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Container(
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
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Etiquetas',
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        onSubmitted: (_) => _createTag(),
                        onChanged: (_) {
                          if (_nameInvalid) {
                            setState(() => _nameInvalid = false);
                          }
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Nombre de la etiqueta',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: _nameInvalid
                              ? AppColors.dangerRed.withOpacity(0.06)
                              : AppColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _nameInvalid
                                  ? AppColors.dangerRed
                                  : AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _nameInvalid
                                  ? AppColors.dangerRed
                                  : AppColors.border,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Agregar etiqueta',
                      onPressed: _createTag,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (tags.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Todavía no hay etiquetas creadas.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: tags.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.label_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 19,
                              color: AppColors.dangerRed,
                            ),
                            onPressed: () =>
                                context.read<CatalogProvider>().removeTag(tag),
                          ),
                        );
                      },
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
