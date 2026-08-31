import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';

class CreateProductDialog extends StatefulWidget {
  final Map<String, dynamic>? product;

  const CreateProductDialog({super.key, this.product});

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? product,
  }) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: CreateProductDialog(product: product),
        );
      },
    );
  }

  @override
  State<CreateProductDialog> createState() =>
      _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  late int _stock;
  late int _minStock;
  late int _maxStock;

  String? _selectedCategory;

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _unitController = TextEditingController();

  final TextEditingController _departmentController =
      TextEditingController();

  final TextEditingController _buyPriceController =
      TextEditingController();

  final TextEditingController _sellPriceController =
      TextEditingController();

  final TextEditingController _barcodeController =
      TextEditingController();

  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;

  final FocusNode _stockFocusNode = FocusNode();

  final FocusNode _minStockFocusNode = FocusNode();

  final FocusNode _maxStockFocusNode = FocusNode();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _stock = _readInt(product?['stock'], 0);

    _minStock = _readInt(product?['minStock'], 5);

    _maxStock = _readInt(product?['maxStock'], 40);

    _selectedCategory = product?['category']?.toString();

    _nameController.text = product?['name']?.toString() ?? '';

    _unitController.text = product?['unit']?.toString() ?? '';

    _departmentController.text =
        product?['department']?.toString() ?? '';

    _buyPriceController.text = _readDoubleText(product?['cost']);

    _sellPriceController.text = _readDoubleText(product?['price']);

    _barcodeController.text = product?['barcode']?.toString() ?? '';

    _stockController = TextEditingController(text: '$_stock');

    _minStockController = TextEditingController(text: '$_minStock');

    _maxStockController = TextEditingController(text: '$_maxStock');

    _setupFocusSelection(_stockFocusNode, _stockController);

    _setupFocusSelection(_minStockFocusNode, _minStockController);

    _setupFocusSelection(_maxStockFocusNode, _maxStockController);
  }

  int _readInt(dynamic value, int fallback) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _readDoubleText(dynamic value) {
    if (value is num) {
      return value.toString();
    }

    return value?.toString() ?? '';
  }

  void _setupFocusSelection(
    FocusNode node,
    TextEditingController controller,
  ) {
    node.addListener(() {
      if (!node.hasFocus) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!node.hasFocus || !mounted) {
          return;
        }

        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _departmentController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _barcodeController.dispose();

    _stockController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();

    _stockFocusNode.dispose();
    _minStockFocusNode.dispose();
    _maxStockFocusNode.dispose();

    super.dispose();
  }

  void _updateStock(int value) {
    if (value < 0) {
      return;
    }

    setState(() {
      _stock = value;
      _stockController.text = '$_stock';
    });
  }

  void _updateMinStock(int value) {
    if (value < 0) {
      return;
    }

    setState(() {
      _minStock = value;
      _minStockController.text = '$_minStock';
    });
  }

  void _updateMaxStock(int value) {
    if (value < 0) {
      return;
    }

    setState(() {
      _maxStock = value;
      _maxStockController.text = '$_maxStock';
    });
  }

  void _saveProduct() {
    final name = _nameController.text.trim();

    final unit = _unitController.text.trim();

    final department = _departmentController.text.trim();

    final cost =
        double.tryParse(
          _buyPriceController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    final price =
        double.tryParse(
          _sellPriceController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    final barcode = _barcodeController.text.trim();

    if (name.isEmpty) {
      _showError('Ingresa el nombre del producto.');
      return;
    }

    if (unit.isEmpty) {
      _showError('Ingresa la unidad o medida.');
      return;
    }

    if (department.isEmpty) {
      _showError('Ingresa el departamento.');
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showError('Selecciona una categoría.');
      return;
    }

    if (cost < 0) {
      _showError('El precio de compra no puede ser negativo.');
      return;
    }

    if (price <= 0) {
      _showError('Ingresa un precio de venta válido.');
      return;
    }

    if (_minStock > _maxStock) {
      _showError('El stock mínimo no puede ser mayor al máximo.');
      return;
    }

    if (_stock < 0) {
      _showError('El stock no puede ser negativo.');
      return;
    }

    final existingProduct = widget.product;

    final product = Product(
      id: existingProduct?['id']?.toString() ?? '',
      name: name,
      unit: unit,
      department: department,
      cost: cost,
      price: price,
      stock: _stock,
      minStock: _minStock,
      maxStock: _maxStock,
      category: _selectedCategory!,
      barcode: barcode,
    );

    final provider = context.read<ProductProvider>();

    if (_isEditing) {
      provider.updateProduct(product);
    } else {
      provider.addProduct(product);
    }

    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const Color flapColor = AppColors.cardExtensionBackground;

    const double cardVisibleRightPadding = 85.0;

    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 155,
                child: Container(
                  decoration: const BoxDecoration(
                    color: flapColor,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    left: 70,
                    right: 8,
                    top: 12,
                    bottom: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCounterCard(
                        label: 'stock',
                        controller: _stockController,
                        focusNode: _stockFocusNode,
                        onIncrement: () => _updateStock(_stock + 1),
                        onDecrement: () => _updateStock(_stock - 1),
                        onChanged: (value) {
                          _stock = int.tryParse(value) ?? 0;
                        },
                      ),
                      _buildCounterCard(
                        label: 'mín',
                        controller: _minStockController,
                        focusNode: _minStockFocusNode,
                        onIncrement: () =>
                            _updateMinStock(_minStock + 1),
                        onDecrement: () =>
                            _updateMinStock(_minStock - 1),
                        onChanged: (value) {
                          _minStock = int.tryParse(value) ?? 0;
                        },
                      ),
                      _buildCounterCard(
                        label: 'máx',
                        controller: _maxStockController,
                        focusNode: _maxStockFocusNode,
                        onIncrement: () =>
                            _updateMaxStock(_maxStock + 1),
                        onDecrement: () =>
                            _updateMaxStock(_maxStock - 1),
                        onChanged: (value) {
                          _maxStock = int.tryParse(value) ?? 0;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  right: cardVisibleRightPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isEditing
                                    ? 'Editar Producto'
                                    : 'Nuevo Producto',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(15),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: AppColors.textSecondary,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  color: AppColors.textMuted,
                                  size: 34,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Img',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  _nameController,
                                  AppStrings.productNameHint,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTextField(
                                  _unitController,
                                  AppStrings.unitHint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  _buyPriceController,
                                  AppStrings.purchasePriceHint,
                                  prefixText: '\$ ',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  _sellPriceController,
                                  AppStrings.salePriceHint,
                                  prefixText: '\$ ',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            _barcodeController,
                            AppStrings.barcodeHint,
                            suffixIcon: const Icon(
                              Icons.qr_code_scanner,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            _departmentController,
                            AppStrings.selectDeptHint,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            isDense: true,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Categoría',
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                              filled: true,
                              fillColor: AppColors.inputBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                            ),
                            items: AppCategories.all
                                .skip(1)
                                .map(
                                  (category) =>
                                      DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _saveProduct,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          AppStrings.saveButton,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounterCard({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onIncrement,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.7),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 55,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.1,
                  ),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 1),
                    border: InputBorder.none,
                  ),
                  onChanged: onChanged,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: onDecrement,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.7),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.remove,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    String? prefixText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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
    );
  }
}
