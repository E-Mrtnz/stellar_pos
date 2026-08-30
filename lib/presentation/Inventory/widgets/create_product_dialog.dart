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
  int _stock = 18;
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
  final TextEditingController _buyPriceController =
      TextEditingController();
  final TextEditingController _sellPriceController =
      TextEditingController();
  final TextEditingController _barcodeController =
      TextEditingController();

  late final TextEditingController _stockController;
  final FocusNode _stockFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(text: '$_stock');

    // Selección segura del texto diferida al siguiente frame para evitar el error de SchedulerBinding
    _stockFocusNode.addListener(() {
      if (_stockFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_stockFocusNode.hasFocus && mounted) {
            _stockController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _stockController.text.length,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _stockFocusNode.dispose();
    super.dispose();
  }

  void _updateStock(int newStock) {
    if (newStock < 0) return;
    setState(() {
      _stock = newStock;
      _stockController.text = '$_stock';
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color flapColor = Color(0xFF3B82F6);
    const Color buttonColor = AppColors.primary;

    const double cardVisibleRightPadding = 70.0;

    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ==========================================
              // CAPA 1 (FONDO): SOLAPA LATERAL DERECHA (SÓLIDA)
              // ==========================================
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 140,
                child: Container(
                  decoration: const BoxDecoration(
                    color: flapColor,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // BOTÓN + (DELINEADO CIRCULAR)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _updateStock(_stock + 1),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // FIELD TEXT TRANSPARENTE / EDITABLE PARA EL STOCK (Ajustado a 20px)
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _stockController,
                              focusNode: _stockFocusNode,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    20, // Fuente reducida para soportar 4+ dígitos
                                height: 1.2,
                              ),
                              cursorColor: Colors.white,
                              decoration: const InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null) {
                                  _stock = parsed;
                                } else if (val.isEmpty) {
                                  _stock = 0;
                                }
                              },
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'stock',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BOTÓN - (DELINEADO CIRCULAR)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _updateStock(_stock - 1),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
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
                          bottomLeft: Radius.zero,
                          bottomRight: Radius.zero,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header con X
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

                          // Carga de Imagen
                          Container(
                            height: 135,
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
                                  size: 36,
                                ),
                                SizedBox(height: 6),
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
                          const SizedBox(height: 16),

                          // Campos del Formulario
                          _buildTextField(
                            _nameController,
                            AppStrings.productNameHint,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  _buyPriceController,
                                  AppStrings.purchasePriceHint,
                                  prefixText: '\$ ',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  _sellPriceController,
                                  AppStrings.salePriceHint,
                                  prefixText: '\$ ',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            _barcodeController,
                            AppStrings.barcodeHint,
                            suffixIcon: const Icon(
                              Icons.qr_code_scanner,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
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

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
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
          vertical: 12,
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
          vertical: 12,
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
