import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/widgets/app_confirm_dialog.dart';

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
  State<CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  int _stock = 0;
  int _minStock = 0;
  int _maxStock = 0;

  String? _selectedTag;
  String? _selectedDistributor;

  List<String> get _tags => context.watch<CatalogProvider>().tags;
  List<String> get _distributors =>
      context.watch<ProvidersProvider>().distributors;

  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _barcodeController = TextEditingController();

  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;

  final _stockFocusNode = FocusNode();
  final _minStockFocusNode = FocusNode();
  final _maxStockFocusNode = FocusNode();

  final Set<String> _invalidFields = {};
  OverlayEntry? _validationOverlay;
  Timer? _validationTimer;

  String? _imageData;
  bool _isPickingImage = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final p = widget.product;
    _stock = _readInt(p?['stock']);
    _minStock = _readInt(p?['minStock']);
    _maxStock = _readInt(p?['maxStock']);

    _stockController = TextEditingController(text: '$_stock');
    _minStockController = TextEditingController(text: '$_minStock');
    _maxStockController = TextEditingController(text: '$_maxStock');

    _nameController.text = p?['name']?.toString() ?? '';
    _unitController.text = p?['unit']?.toString() ?? '';
    _buyPriceController.text = p?['cost']?.toString() ?? '';
    _sellPriceController.text = p?['price']?.toString() ?? '';
    _barcodeController.text = p?['barcode']?.toString() ?? '';
    _selectedTag = _nullable(p?['category']);
    _selectedDistributor = _nullable(p?['department']);
    _imageData = _nullable(p?['imageData']);

    _setupFocus(_stockFocusNode, _stockController);
    _setupFocus(_minStockFocusNode, _minStockController);
    _setupFocus(_maxStockFocusNode, _maxStockController);
  }

  String? _nullable(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _price(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  void _setupFocus(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      if (!node.hasFocus) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (node.hasFocus && mounted) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      });
    });
  }

  bool _validate() {
    final invalid = <String>{};

    if (_nameController.text.trim().isEmpty) invalid.add('name');
    if (_unitController.text.trim().isEmpty) invalid.add('unit');
    if (_sellPriceController.text.trim().isEmpty) invalid.add('salePrice');
    if (_stockController.text.trim().isEmpty) invalid.add('stock');
    if (_minStockController.text.trim().isEmpty) invalid.add('minStock');
    if (_maxStockController.text.trim().isEmpty) invalid.add('maxStock');

    setState(() {
      _invalidFields
        ..clear()
        ..addAll(invalid);
    });

    if (invalid.isEmpty) return true;

    _showValidation('Completa los campos obligatorios.');
    return false;
  }

  void _clearError(String field) {
    if (!_invalidFields.contains(field)) return;
    setState(() => _invalidFields.remove(field));
  }

  bool _invalid(String field) => _invalidFields.contains(field);

  void _updateStock(int value) {
    setState(() {
      _stock = value;
      _stockController.text = '$_stock';
      _invalidFields.remove('stock');
    });
  }

  void _updateMinStock(int value) {
    if (value < 0) return;
    setState(() {
      _minStock = value;
      _minStockController.text = '$_minStock';
      _invalidFields.remove('minStock');
    });
  }

  void _updateMaxStock(int value) {
    if (value < 0) return;
    setState(() {
      _maxStock = value;
      _maxStockController.text = '$_maxStock';
      _invalidFields.remove('maxStock');
    });
  }

  int _currentValue(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      List<int>? bytes;

      if (kIsWeb) {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        bytes = result.files.single.bytes;
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        if (image == null) return;
        bytes = await image.readAsBytes();
      }

      if (bytes == null || bytes.isEmpty || !mounted) return;
      setState(() => _imageData = base64Encode(bytes!));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removeImage() => setState(() => _imageData = null);

  Future<void> _save() async {
    if (!_validate()) return;

    final product = Product(
      id: widget.product?['id']?.toString() ?? '',
      name: _nameController.text.trim(),
      unit: _unitController.text.trim(),
      department: _selectedDistributor ?? '',
      cost: _price(_buyPriceController.text),
      price: _price(_sellPriceController.text),
      stock: _readInt(_stockController.text),
      minStock: _readInt(_minStockController.text),
      maxStock: _readInt(_maxStockController.text),
      category: _selectedTag ?? '',
      barcode: _barcodeController.text.trim(),
      imageData: _imageData ?? '',
    );

    final provider = context.read<ProductProvider>();

    if (_isEditing) {
      final confirmed = await AppConfirmDialog.update(
        context,
        itemName: 'este producto',
      );
      if (!confirmed || !mounted) return;

      provider.updateProduct(product);
      AppAlert.show(
        context,
        'El producto se actualizó correctamente.',
        title: 'Producto actualizado',
        type: AppAlertType.success,
      );
    } else {
      provider.addProduct(product);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!_isEditing) return;

    final confirmed = await AppConfirmDialog.delete(
      context,
      itemName: 'este producto',
    );
    if (!confirmed || !mounted) return;

    context
        .read<ProductProvider>()
        .deleteProduct(widget.product!['id'].toString());

    AppAlert.show(
      context,
      'El producto se eliminó correctamente.',
      title: 'Producto eliminado',
      type: AppAlertType.success,
    );

    Navigator.of(context).pop();
  }

  void _showValidation(String message) {
    _validationTimer?.cancel();
    _validationOverlay?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 18,
        left: 20,
        right: 20,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: _ValidationAlert(message: message),
          ),
        ),
      ),
    );

    _validationOverlay = entry;
    overlay.insert(entry);

    _validationTimer = Timer(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
      if (identical(_validationOverlay, entry)) {
        _validationOverlay = null;
      }
    });
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _validationOverlay?.remove();

    for (final controller in [
      _nameController,
      _unitController,
      _buyPriceController,
      _sellPriceController,
      _barcodeController,
      _stockController,
      _minStockController,
      _maxStockController,
    ]) {
      controller.dispose();
    }

    _stockFocusNode.dispose();
    _minStockFocusNode.dispose();
    _maxStockFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Color(0xFF3B82F6),
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
                      _counter(
                        'stock',
                        _stockController,
                        _stockFocusNode,
                        () => _updateStock(
                          _currentValue(_stockController, _stock) + 1,
                        ),
                        () => _updateStock(
                          _currentValue(_stockController, _stock) - 1,
                        ),
                        (value) {
                          _stock = _readInt(value);
                          _clearError('stock');
                        },
                        _invalid('stock'),
                      ),
                      _counter(
                        'mín',
                        _minStockController,
                        _minStockFocusNode,
                        () => _updateMinStock(
                          _currentValue(_minStockController, _minStock) + 1,
                        ),
                        () => _updateMinStock(
                          _currentValue(_minStockController, _minStock) - 1,
                        ),
                        (value) {
                          _minStock = _readInt(value);
                          _clearError('minStock');
                        },
                        _invalid('minStock'),
                      ),
                      _counter(
                        'máx',
                        _maxStockController,
                        _maxStockFocusNode,
                        () => _updateMaxStock(
                          _currentValue(_maxStockController, _maxStock) + 1,
                        ),
                        () => _updateMaxStock(
                          _currentValue(_maxStockController, _maxStock) - 1,
                        ),
                        (value) {
                          _maxStock = _readInt(value);
                          _clearError('maxStock');
                        },
                        _invalid('maxStock'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 85),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _isEditing
                                      ? 'Editar Producto'
                                      : 'Nuevo Producto',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (_isEditing)
                                IconButton(
                                  onPressed: _delete,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.dangerRed,
                                    size: 21,
                                  ),
                                ),
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _imagePicker(),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _field(
                                  _nameController,
                                  AppStrings.productNameHint,
                                  invalid: _invalid('name'),
                                  changed: (_) => _clearError('name'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _field(
                                  _unitController,
                                  'Cant.',
                                  invalid: _invalid('unit'),
                                  changed: (_) => _clearError('unit'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _buyPriceController,
                                  AppStrings.purchasePriceHint,
                                  prefix: '\$ ',
                                  type: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  formatter: const DecimalInputFormatter(
                                    decimalDigits: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _field(
                                  _sellPriceController,
                                  AppStrings.salePriceHint,
                                  prefix: '\$ ',
                                  invalid: _invalid('salePrice'),
                                  changed: (_) => _clearError('salePrice'),
                                  type: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  formatter: const DecimalInputFormatter(
                                    decimalDigits: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _field(
                            _barcodeController,
                            AppStrings.barcodeHint,
                            suffix: const Icon(
                              Icons.qr_code_scanner,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _dropdown(
                                  AppStrings.selectTagHint,
                                  _selectedTag,
                                  _tags,
                                  (value) =>
                                      setState(() => _selectedTag = value),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _dropdown(
                                  AppStrings.selectDeptHint,
                                  _selectedDistributor,
                                  _distributors,
                                  (value) => setState(
                                    () => _selectedDistributor = value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _save,
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
                        child: Text(
                          _isEditing ? 'Actualizar' : AppStrings.saveButton,
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

  Widget _counter(
    String label,
    TextEditingController controller,
    FocusNode node,
    VoidCallback inc,
    VoidCallback dec,
    ValueChanged<String> changed,
    bool invalid,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: invalid
              ? Colors.red.shade400
              : Colors.white.withOpacity(0.5),
          width: invalid ? 1.8 : 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: inc,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 14),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 55,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  focusNode: node,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^-?\d*'),
                    ),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white60),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 1),
                    border: InputBorder.none,
                  ),
                  onChanged: changed,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: dec,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70),
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

  Widget _field(
    TextEditingController controller,
    String hint, {
    String? prefix,
    Widget? suffix,
    TextInputType? type,
    TextInputFormatter? formatter,
    bool invalid = false,
    ValueChanged<String>? changed,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      inputFormatters: formatter == null ? null : [formatter],
      onChanged: changed,
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
        prefixText: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: invalid
            ? Colors.red.withOpacity(0.06)
            : AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: invalid ? Colors.red : AppColors.border,
            width: invalid ? 1.8 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: invalid ? Colors.red : AppColors.border,
            width: invalid ? 1.8 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: invalid ? Colors.red : AppColors.primary,
            width: 1.8,
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String hint,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String?>(
      initialValue: items.contains(value) ? value : null,
      isDense: true,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
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
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Sin seleccionar',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...items.map(
          (item) => DropdownMenuItem<String?>(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _imagePicker() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_imageData == null)
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(_imageData!),
                    fit: BoxFit.contain,
                  ),
                ),
              if (_isPickingImage)
                const Center(child: CircularProgressIndicator()),
              if (_imageData != null && !_isPickingImage)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    onPressed: _removeImage,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.dangerRed,
                    ),
                  ),
                ),
            ],
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
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DecimalInputFormatter extends TextInputFormatter {
  final int decimalDigits;

  const DecimalInputFormatter({required this.decimalDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final pattern = RegExp(
      r'^\d*(\.\d{0,' + decimalDigits.toString() + r'})?$',
    );

    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
