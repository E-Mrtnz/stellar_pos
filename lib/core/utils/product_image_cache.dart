import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Reuses decoded product image bytes across widget rebuilds.
///
/// Product cards can rebuild frequently because cart, search, or other POS
/// state changes. The decoded bytes are cached by product id and exact payload.
/// Async decoding is queued so a newly visible batch of products does not
/// decode every image on the UI thread at once.
class ProductImageCache {
  ProductImageCache._();

  static const int _maxEntries = 300;
  static const int _maxConcurrentDecodes = 2;

  static final Map<String, _CachedImage> _cache = <String, _CachedImage>{};
  static final Map<String, Future<Uint8List?>> _pending =
      <String, Future<Uint8List?>>{};
  static final List<_DecodeRequest> _queue = <_DecodeRequest>[];
  static int _activeDecodes = 0;

  static Uint8List? getBytes({
    required String productId,
    required String imageData,
  }) {
    final normalized = _normalize(imageData);
    if (normalized.isEmpty) return null;

    final cached = _cache[productId];
    if (cached != null && cached.source == normalized) {
      return cached.bytes;
    }

    try {
      final bytes = _decodeBase64(normalized);
      _store(productId, normalized, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> getBytesAsync({
    required String productId,
    required String imageData,
  }) {
    final normalized = _normalize(imageData);
    if (normalized.isEmpty) return Future<Uint8List?>.value(null);

    final cached = _cache[productId];
    if (cached != null && cached.source == normalized) {
      return Future<Uint8List?>.value(cached.bytes);
    }

    final existing = _pending[productId];
    if (existing != null) return existing;

    final completer = Completer<Uint8List?>();
    _pending[productId] = completer.future;
    _queue.add(
      _DecodeRequest(
        productId: productId,
        source: normalized,
        completer: completer,
      ),
    );
    _pumpQueue();
    return completer.future;
  }

  static void invalidate(String productId) {
    _cache.remove(productId);
  }

  static void clear() {
    _cache.clear();
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final comma = trimmed.indexOf(',');
    if (trimmed.startsWith('data:') && comma >= 0) {
      return trimmed.substring(comma + 1);
    }
    return trimmed;
  }

  static Uint8List _decodeBase64(String value) => base64Decode(value);

  static void _pumpQueue() {
    while (_activeDecodes < _maxConcurrentDecodes && _queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      _activeDecodes++;
      _decodeRequest(request);
    }
  }

  static Future<void> _decodeRequest(_DecodeRequest request) async {
    Uint8List? bytes;
    try {
      bytes = await compute(_decodeBase64, request.source);
      if (bytes != null) {
        _store(request.productId, request.source, bytes);
      }
      request.completer.complete(bytes);
    } catch (_) {
      request.completer.complete(null);
    } finally {
      _pending.remove(request.productId);
      _activeDecodes--;
      _pumpQueue();
    }
  }

  static void _store(String productId, String source, Uint8List bytes) {
    _cache[productId] = _CachedImage(source: source, bytes: bytes);
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class _DecodeRequest {
  final String productId;
  final String source;
  final Completer<Uint8List?> completer;

  const _DecodeRequest({
    required this.productId,
    required this.source,
    required this.completer,
  });
}

class _CachedImage {
  final String source;
  final Uint8List bytes;

  const _CachedImage({
    required this.source,
    required this.bytes,
  });
}
