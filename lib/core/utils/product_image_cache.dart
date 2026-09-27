import 'dart:convert';
import 'dart:typed_data';

/// Reuses decoded product image bytes across widget rebuilds.
///
/// Product cards can rebuild frequently because cart, search, or other POS
/// state changes. Decoding the same base64 payload on every build is wasted
/// CPU work, so the bytes are cached by product id and payload fingerprint.
class ProductImageCache {
  ProductImageCache._();

  static const int _maxEntries = 300;
  static final Map<String, _CachedImage> _cache = <String, _CachedImage>{};

  static Uint8List? getBytes({
    required String productId,
    required String imageData,
  }) {
    final normalized = imageData.trim();
    if (normalized.isEmpty) return null;

    final cached = _cache[productId];
    if (cached != null && cached.source == normalized) {
      return cached.bytes;
    }

    try {
      final bytes = base64Decode(normalized);
      _cache[productId] = _CachedImage(
        source: normalized,
        bytes: bytes,
      );
      _trim();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static void invalidate(String productId) {
    _cache.remove(productId);
  }

  static void clear() {
    _cache.clear();
  }

  static void _trim() {
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class _CachedImage {
  final String source;
  final Uint8List bytes;

  const _CachedImage({
    required this.source,
    required this.bytes,
  });
}
