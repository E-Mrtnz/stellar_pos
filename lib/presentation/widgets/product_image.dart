import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:stellar_pos/core/utils/product_image_cache.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class ProductImage extends StatelessWidget {
  final String productId;
  final String imageData;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData placeholderIcon;
  final double placeholderIconSize;
  final bool showBorder;

  const ProductImage({
    super.key,
    required this.productId,
    required this.imageData,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = BorderRadius.zero,
    this.placeholderIcon = Icons.image_outlined,
    this.placeholderIconSize = 20,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ProductImageCache.getBytesAsync(
        productId: productId,
        imageData: imageData,
      ),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;

        return ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: showBorder
                  ? Border.all(color: AppColors.border)
                  : null,
              borderRadius: borderRadius,
            ),
            alignment: Alignment.center,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    width: width,
                    height: height,
                    fit: fit,
                    gaplessPlayback: true,
                  )
                : loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        placeholderIcon,
                        size: placeholderIconSize,
                        color: AppColors.textMuted,
                      ),
          ),
        );
      },
    );
  }
}
