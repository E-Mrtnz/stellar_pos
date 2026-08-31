import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class CreateProductDialog extends StatefulWidget {
  const CreateProductDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreateProductDialog(),
      ),
    );
  }

  @override
  State<CreateProductDialog> createState() =>
      _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  // Valores de los 3 contadores
  int _stock = 18;
  int _minStock = 0;
  int _maxStock = 0;

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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _buyPriceController =
      TextEditingController();
  final TextEditingController _sellPriceController =
      TextEditingController();
  final TextEditingController _barcodeController =
      TextEditingController();

  // Controladores y FocusNodes para la solapa
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;

  final FocusNode _stockFocusNode = FocusNode();
  final FocusNode _minStockFocusNode = FocusNode();
  final FocusNode _maxStockFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _stockController = TextEditingController(text: '$_stock');
    _minStockController = TextEditingController(text: '$_minStock');
    _maxStockController = TextEditingController(text: '$_maxStock');

    _setupFocusSelection(_stockFocusNode, _stockController);
    _setupFocusSelection(_minStockFocusNode, _minStockController);
    _setupFocusSelection(_maxStockFocusNode, _maxStockController);
  }

  void _setupFocusSelection(
    FocusNode node,
    TextEditingController controller,
  ) {
    node.addListener(() {
      if (node.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (node.hasFocus && mounted) {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
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

  // Métodos para actualizar contadores
  void _updateStock(int value) {
    if (value < 0) return;

    setState(() {
      _stock = value;
      _stockController.text = '$_stock';
    });
  }

  void _updateMinStock(int value) {
    if (value < 0) return;

    setState(() {
      _minStock = value;
      _minStockController.text = '$_minStock';
    });
  }

  void _updateMaxStock(int value) {
    if (value < 0) return;

    setState(() {
      _maxStock = value;
      _maxStockController.text = '$_maxStock';
    });
  }

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
              // ==========================================
              // CAPA 1 (FONDO): SOLAPA LATERAL DERECHA
              // ==========================================
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
                      // 1. Contador Stock
                      _buildCounterCard(
                        label: 'stock',
                        controller: _stockController,
                        focusNode: _stockFocusNode,
                        onIncrement: () => _updateStock(_stock + 1),
                        onDecrement: () => _updateStock(_stock - 1),
                        onChanged: (val) {
                          _stock = int.tryParse(val) ?? 0;
                        },
                      ),

                      // 2. Contador Mínimo
                      _buildCounterCard(
                        label: 'mín',
                        controller: _minStockController,
                        focusNode: _minStockFocusNode,
                        onIncrement: () =>
                            _updateMinStock(_minStock + 1),
                        onDecrement: () =>
                            _updateMinStock(_minStock - 1),
                        onChanged: (val) {
                          _minStock = int.tryParse(val) ?? 0;
                        },
                      ),

                      // 3. Contador Máximo
                      _buildCounterCard(
                        label: 'máx',
                        controller: _maxStockController,
                        focusNode: _maxStockFocusNode,
                        onIncrement: () =>
                            _updateMaxStock(_maxStock + 1),
                        onDecrement: () =>
                            _updateMaxStock(_maxStock - 1),
                        onChanged: (val) {
                          _maxStock = int.tryParse(val) ?? 0;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ==========================================
              // CAPA 2 (FRENTE): CARD BLANCA Y BOTÓN GUARDAR
              // ==========================================
              Padding(
                padding: const EdgeInsets.only(
                  right: cardVisibleRightPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CARD BLANCA DEL FORMULARIO
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
                              const Text(
                                'Nuevo Producto',
                                style: TextStyle(
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
                                  padding: EdgeInsets.all(4.0),
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

                          // FILA: Nombre del Producto + Medida / Unidad
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
                                flex: 1,
                                child: _buildTextField(
                                  _unitController,
                                  'Cant.',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // FILA: Precio de compra + Precio de venta
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

                          // Departamento y etiquetas son OPCIONALES.
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  hint: AppStrings.selectTagHint,
                                  value: _selectedTag,
                                  items: _tags,
                                  onChanged: (val) => setState(
                                    () => _selectedTag = val,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDropdown(
                                  hint: AppStrings.selectDeptHint,
                                  value: _selectedDept,
                                  items: _departments,
                                  onChanged: (val) => setState(
                                    () => _selectedDept = val,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // BOTÓN GUARDAR
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
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

  // WIDGET AUXILIAR PARA CADA TARJETA DE CONTADOR (SOLAPA)
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
          // Botón +
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

          // Campo numérico y etiqueta
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

          // Botón -
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Permite cualquier cantidad de dígitos antes del punto decimal
/// y limita únicamente la cantidad de dígitos después del punto.
class DecimalInputFormatter extends TextInputFormatter {
  final int decimalDigits;

  const DecimalInputFormatter({required this.decimalDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Permitir campo vacío.
    if (text.isEmpty) {
      return newValue;
    }

    // Solo permite:
    // - cualquier cantidad de dígitos antes del punto
    // - un único punto decimal
    // - hasta `decimalDigits` dígitos después del punto
    final pattern = RegExp('^\\d*(\\.\\d{0,$decimalDigits})?\$');

    if (pattern.hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}
