import 'dart:async';

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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreateProductDialog(product: product),
      ),
    );
  }

  @override
  State<CreateProductDialog> createState() =>
      _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  // ============================================================
  // STOCK
  // ============================================================

  int _stock = 0;
  int _minStock = 0;
  int _maxStock = 0;

  // ============================================================
  // OPCIONES
  // ============================================================

  String? _selectedTag;
  String? _selectedDept;

  final List<String> _tags = [
    'Sodas',
    'Jugos',
    'Sopas Instantáneas',
    'Snacks',
  ];

  final List<String> _departments = [
    'Coca-Cola',
    'Pepsi',
    'Maggi',
    'Sabritas',
  ];

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _unitController = TextEditingController();

  final TextEditingController _buyPriceController =
      TextEditingController();

  final TextEditingController _sellPriceController =
      TextEditingController();

  final TextEditingController _barcodeController =
      TextEditingController();

  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;

  // ============================================================
  // FOCUS
  // ============================================================

  final FocusNode _stockFocusNode = FocusNode();
  final FocusNode _minStockFocusNode = FocusNode();
  final FocusNode _maxStockFocusNode = FocusNode();

  // ============================================================
  // VALIDACIÓN
  // ============================================================

  final Set<String> _invalidFields = <String>{};

  OverlayEntry? _validationOverlay;
  Timer? _validationTimer;

  bool get _isEditing => widget.product != null;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _stock = _readInt(product?['stock']);
    _minStock = _readInt(product?['minStock']);
    _maxStock = _readInt(product?['maxStock']);

    _stockController = TextEditingController(text: '$_stock');

    _minStockController = TextEditingController(text: '$_minStock');

    _maxStockController = TextEditingController(text: '$_maxStock');

    _nameController.text = product?['name']?.toString() ?? '';

    _unitController.text = product?['unit']?.toString() ?? '';

    _buyPriceController.text = _formatExistingPrice(product?['cost']);

    _sellPriceController.text = _formatExistingPrice(product?['price']);

    _barcodeController.text = product?['barcode']?.toString() ?? '';

    _selectedTag = _nullableString(product?['category']);

    _selectedDept = _nullableString(product?['department']);

    _setupFocusSelection(_stockFocusNode, _stockController);

    _setupFocusSelection(_minStockFocusNode, _minStockController);

    _setupFocusSelection(_maxStockFocusNode, _maxStockController);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatExistingPrice(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      return value.toString();
    }

    return value.toString();
  }

  String? _nullableString(dynamic value) {
    final result = value?.toString().trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
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

  // ============================================================
  // VALIDACIÓN
  // ============================================================

  bool _validateRequiredFields() {
    final invalidFields = <String>{};

    if (_nameController.text.trim().isEmpty) {
      invalidFields.add('name');
    }

    if (_unitController.text.trim().isEmpty) {
      invalidFields.add('unit');
    }

    if (_sellPriceController.text.trim().isEmpty) {
      invalidFields.add('salePrice');
    }

    if (_stockController.text.trim().isEmpty) {
      invalidFields.add('stock');
    }

    if (_minStockController.text.trim().isEmpty) {
      invalidFields.add('minStock');
    }

    if (_maxStockController.text.trim().isEmpty) {
      invalidFields.add('maxStock');
    }

    setState(() {
      _invalidFields
        ..clear()
        ..addAll(invalidFields);
    });

    if (invalidFields.isEmpty) {
      return true;
    }

    _showValidationAlert(_buildValidationMessage(invalidFields));

    return false;
  }

  String _buildValidationMessage(Set<String> invalidFields) {
    final fieldNames = <String>[];

    if (invalidFields.contains('name')) {
      fieldNames.add('Nombre del producto');
    }

    if (invalidFields.contains('unit')) {
      fieldNames.add('Unidad de medida');
    }

    if (invalidFields.contains('salePrice')) {
      fieldNames.add('Precio de venta');
    }

    if (invalidFields.contains('stock')) {
      fieldNames.add('Stock');
    }

    if (invalidFields.contains('minStock')) {
      fieldNames.add('Stock mínimo');
    }

    if (invalidFields.contains('maxStock')) {
      fieldNames.add('Stock máximo');
    }

    return ''
        '${fieldNames.map((field) => '• $field').join('\n')}';
  }

  bool _isInvalid(String field) {
    return _invalidFields.contains(field);
  }

  void _clearFieldError(String field) {
    if (!_invalidFields.contains(field)) {
      return;
    }

    setState(() {
      _invalidFields.remove(field);
    });
  }

  // ============================================================
  // GUARDAR PRODUCTO
  // ============================================================

  Future<void> _saveProduct() async {
    if (!_validateRequiredFields()) {
      return;
    }

    final provider = context.read<ProductProvider>();

    final product = Product(
      id: widget.product?['id']?.toString() ?? '',
      name: _nameController.text.trim(),
      unit: _unitController.text.trim(),
      department: _selectedDept ?? '',
      cost: _parsePrice(_buyPriceController.text),
      price: _parsePrice(_sellPriceController.text),
      stock: _readInt(_stockController.text),
      minStock: _readInt(_minStockController.text),
      maxStock: _readInt(_maxStockController.text),
      category: _selectedTag ?? '',
      barcode: _barcodeController.text.trim(),
    );

    if (_isEditing) {
      provider.updateProduct(product);
    } else {
      provider.addProduct(product);
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ============================================================
  // STOCK
  // ============================================================

  void _updateStock(int value) {
    if (value < 0) {
      return;
    }

    setState(() {
      _stock = value;
      _stockController.text = '$_stock';
      _clearFieldError('stock');
    });
  }

  void _updateMinStock(int value) {
    if (value < 0) {
      return;
    }

    setState(() {
      _minStock = value;
      _minStockController.text = '$_minStock';
      _clearFieldError('minStock');
    });
  }

  void _updateMaxStock(int value) {
    if (value < 0) {
      return;
    }

    setState(() {
      _maxStock = value;
      _maxStockController.text = '$_maxStock';
      _clearFieldError('maxStock');
    });
  }

  // ============================================================
  // PRECIOS
  // ============================================================

  double _parsePrice(String value) {
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return 0.0;
    }

    return double.tryParse(normalized) ?? 0.0;
  }

  // ============================================================
  // ALERTA
  // ============================================================

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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _validationTimer?.cancel();
    _validationOverlay?.remove();

    _nameController.dispose();
    _unitController.dispose();
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const Color flapColor = Color(0xFF3B82F6);
    const Color buttonColor = AppColors.primary;
    const double cardVisibleRightPadding = 85.0;

    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ==================================================
              // SOLAPA LATERAL
              // ==================================================
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
                        isInvalid: _isInvalid('stock'),
                        onIncrement: () => _updateStock(_stock + 1),
                        onDecrement: () => _updateStock(_stock - 1),
                        onChanged: (value) {
                          _stock = _readInt(value);
                          _clearFieldError('stock');
                        },
                      ),
                      _buildCounterCard(
                        label: 'mín',
                        controller: _minStockController,
                        focusNode: _minStockFocusNode,
                        isInvalid: _isInvalid('minStock'),
                        onIncrement: () =>
                            _updateMinStock(_minStock + 1),
                        onDecrement: () =>
                            _updateMinStock(_minStock - 1),
                        onChanged: (value) {
                          _minStock = _readInt(value);
                          _clearFieldError('minStock');
                        },
                      ),
                      _buildCounterCard(
                        label: 'máx',
                        controller: _maxStockController,
                        focusNode: _maxStockFocusNode,
                        isInvalid: _isInvalid('maxStock'),
                        onIncrement: () =>
                            _updateMaxStock(_maxStock + 1),
                        onDecrement: () =>
                            _updateMaxStock(_maxStock - 1),
                        onChanged: (value) {
                          _maxStock = _readInt(value);
                          _clearFieldError('maxStock');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // CARD PRINCIPAL
              // ==================================================
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
                          // ======================================
                          // HEADER
                          // ======================================
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

                          // ======================================
                          // IMAGEN
                          // ======================================
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

                          // ======================================
                          // NOMBRE + UNIDAD
                          // ======================================
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  _nameController,
                                  AppStrings.productNameHint,
                                  isInvalid: _isInvalid('name'),
                                  onChanged: (_) =>
                                      _clearFieldError('name'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: _buildTextField(
                                  _unitController,
                                  'Cant.',
                                  isInvalid: _isInvalid('unit'),
                                  onChanged: (_) =>
                                      _clearFieldError('unit'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ======================================
                          // PRECIOS
                          // ======================================
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
                                  inputFormatters: const [
                                    DecimalInputFormatter(
                                      decimalDigits: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  _sellPriceController,
                                  AppStrings.salePriceHint,
                                  prefixText: '\$ ',
                                  isInvalid: _isInvalid('salePrice'),
                                  onChanged: (_) =>
                                      _clearFieldError('salePrice'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: const [
                                    DecimalInputFormatter(
                                      decimalDigits: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ======================================
                          // CÓDIGO DE BARRAS
                          // OPCIONAL
                          // ======================================
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

                          // ======================================
                          // ETIQUETA + DEPARTAMENTO
                          // AMBOS OPCIONALES
                          // ======================================
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  hint: AppStrings.selectTagHint,
                                  value: _selectedTag,
                                  items: _tags,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTag = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDropdown(
                                  hint: AppStrings.selectDeptHint,
                                  value: _selectedDept,
                                  items: _departments,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDept = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // BOTÓN GUARDAR
                    // ==================================================
                    InkWell(
                      onTap: _saveProduct,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: buttonColor,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _isEditing
                              ? 'Actualizar'
                              : AppStrings.saveButton,
                          style: const TextStyle(
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

  // ============================================================
  // COUNTER CARD
  // ============================================================

  Widget _buildCounterCard({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required ValueChanged<String> onChanged,
    bool isInvalid = false,
  }) {
    final borderColor = isInvalid
        ? Colors.red.shade400
        : Colors.white.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isInvalid ? 1.8 : 1.2,
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

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    String? prefixText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isInvalid = false,
    ValueChanged<String>? onChanged,
  }) {
    final borderColor = isInvalid
        ? Colors.red.shade500
        : AppColors.border;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textPrimary,
      ),
      onChanged: onChanged,
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
        fillColor: isInvalid
            ? Colors.red.withOpacity(0.06)
            : AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: borderColor,
            width: isInvalid ? 1.8 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: borderColor,
            width: isInvalid ? 1.8 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isInvalid ? Colors.red.shade500 : AppColors.primary,
            width: 1.8,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
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
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ================================================================
// ALERTA DE VALIDACIÓN
// ================================================================

class _ValidationAlert extends StatelessWidget {
  final String message;

  const _ValidationAlert({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: AppColors.warningOrange,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Campos requeridos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Los siguientes campos del producto '
                      'son obligatorios:\n$message',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.35,
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
}

// ================================================================
// FORMATEADOR DECIMAL
// ================================================================

class DecimalInputFormatter extends TextInputFormatter {
  final int decimalDigits;

  const DecimalInputFormatter({required this.decimalDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    final pattern = RegExp('^\\d*(\\.\\d{0,$decimalDigits})?\$');

    if (pattern.hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}
