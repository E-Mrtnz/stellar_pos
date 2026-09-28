import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/utils/product_image_cache.dart';

class ProductImage extends StatefulWidget {
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
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  late Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _load();
  }

  @override
  void didUpdateWidget(covariant ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        oldWidget.imageData != widget.imageData) {
      _imageFuture = _load();
    }
  }

  Future<Uint8List?> _load() {
    return ProductImageCache.getBytesAsync(
      productId: widget.productId,
      imageData: widget.imageData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;

        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: widget.showBorder
                  ? Border.all(color: AppColors.border)
                  : null,
              borderRadius: widget.borderRadius,
            ),
            alignment: Alignment.center,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    width: widget.width,
                    height: widget.height,
                    fit: widget.fit,
                    gaplessPlayback: true,
                  )
                : loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.placeholderIcon,
                        size: widget.placeholderIconSize,
                        color: AppColors.textMuted,
                      ),
          ),
        );
      },
    );
  }
}
