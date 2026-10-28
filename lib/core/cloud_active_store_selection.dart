import 'package:shared_preferences/shared_preferences.dart';

/// Persists only the user's explicit cloud-store choice on this device.
/// This preference does not enable synchronization or affect local checkout.
abstract interface class ActiveCloudStoreSelection {
  Future<String?> read(String userId);
  Future<void> write(String userId, String storeId);
  Future<void> clear(String userId);
}

class SharedPreferencesActiveCloudStoreSelection
    implements ActiveCloudStoreSelection {
  const SharedPreferencesActiveCloudStoreSelection();

  String _key(String userId) {
    if (userId.trim().isEmpty || userId.contains('/')) {
      throw ArgumentError.value(
        userId,
        'userId',
        'Identificador de usuario inválido.',
      );
    }
    return 'cloud_active_store_v1_$userId';
  }

  bool _isValidStoreId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(value);

  @override
  Future<String?> read(String userId) async {
    final value =
        (await SharedPreferences.getInstance()).getString(_key(userId));
    if (value == null || !_isValidStoreId(value)) return null;
    return value;
  }

  @override
  Future<void> write(String userId, String storeId) async {
    if (!_isValidStoreId(storeId)) {
      throw ArgumentError.value(
        storeId,
        'storeId',
        'Identificador de tienda inválido.',
      );
    }
    final saved = await (await SharedPreferences.getInstance())
        .setString(_key(userId), storeId);
    if (!saved) {
      throw StateError('No se pudo persistir la tienda seleccionada.');
    }
  }

  @override
  Future<void> clear(String userId) async {
    await (await SharedPreferences.getInstance()).remove(_key(userId));
  }
}
