import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_product_dialog.dart';

class CreateProductWithImageDialog {
  const CreateProductWithImageDialog._();

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? product,
  }) async {
    final provider = context.read<ProductProvider>();
    final productId = product?['id']?.toString();
    final originalProduct = productId == null
        ? null
        : provider.findById(productId);
    final existingIds = provider.products.map((item) => item.id).toSet();

    String? selectedImageData = _readImageData(product?['imageData']);

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            width: 480,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CreateProductDialog(product: product),
                _ProductImagePickerOverlay(
                  initialImageData: selectedImageData,
                  onImageChanged: (value) {
                    selectedImageData = value;
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (productId != null) {
      final currentProduct = provider.findById(productId);

      if (currentProduct != null &&
          !identical(currentProduct, originalProduct)) {
        provider.updateProduct(
          currentProduct.copyWith(
            imageData: selectedImageData ?? '',
          ),
        );
      }

      return;
    }

    if (selectedImageData == null) {
      return;
    }

    dynamic newProduct;

    for (final item in provider.products) {
      if (!existingIds.contains(item.id)) {
        newProduct = item;
        break;
      }
    }

    if (newProduct == null) {
      return;
    }

    provider.updateProduct(
      newProduct.copyWith(imageData: selectedImageData!),
    );
  }

  static String? _readImageData(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}

class _ProductImagePickerOverlay extends StatefulWidget {
  final String? initialImageData;
  final ValueChanged<String?> onImageChanged;

  const _ProductImagePickerOverlay({
    required this.initialImageData,
    required this.onImageChanged,
  });

  @override
  State<_ProductImagePickerOverlay> createState() =>
      _ProductImagePickerOverlayState();
}

class _ProductImagePickerOverlayState
    extends State<_ProductImagePickerOverlay> {
  String? _imageData;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _imageData = widget.initialImageData;
  }

  Future<void> _pickImage() async {
    if (_isPicking) return;

    // Keep the picker call directly inside the pointer event. This is
    // important on the web because browsers may block file dialogs that are
    // no longer associated with a user gesture.
    setState(() => _isPicking = true);

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (bytes.isEmpty || !mounted) {
        return;
      }

      final encoded = base64Encode(bytes);

      setState(() => _imageData = encoded);
      widget.onImageChanged(encoded);
    } catch (error) {
      debugPrint('Error al seleccionar imagen: $error');
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _removeImage() {
    setState(() => _imageData = null);
    widget.onImageChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(12));

    return Positioned(
      left: 22,
      right: 107,
      top: 82,
      height: 120,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: borderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: InkWell(
              onTap: _pickImage,
              borderRadius: borderRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_imageData != null)
                    ClipRRect(
                      borderRadius: borderRadius,
                      child: _buildImage(),
                    )
                  else
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.textMuted,
                          size: 42,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Img',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  if (_isPicking)
                    Container(
                      color: Colors.black.withOpacity(0.35),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_imageData != null && !_isPicking)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Material(
                        color: AppColors.dangerRed,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _removeImage,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    try {
      return Image.memory(
        base64Decode(_imageData!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } catch (_) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
          size: 42,
        ),
      );
    }
  }
}
