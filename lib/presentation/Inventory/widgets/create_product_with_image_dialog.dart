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

      // CreateProductDialog replaces the Product instance only when the
      // user actually saves. This prevents an image change from being
      // applied when the dialog is simply closed.
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

    setState(() => _isPicking = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        return;
      }

      final encoded = base64Encode(bytes);

      if (!mounted) return;

      setState(() => _imageData = encoded);
      widget.onImageChanged(encoded);
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
    return Positioned(
      left: 22,
      right: 107,
      top: 82,
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickImage,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imageData != null) _buildImage(),
                if (_imageData == null)
                  const ColoredBox(color: Colors.transparent),
                if (_isPicking)
                  Container(
                    color: Colors.black.withOpacity(0.35),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (!_isPicking)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        onTap: _pickImage,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_imageData != null && !_isPicking)
                  Positioned(
                    left: 8,
                    top: 8,
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
    );
  }

  Widget _buildImage() {
    try {
      return Image.memory(
        base64Decode(_imageData!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
