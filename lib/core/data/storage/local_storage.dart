import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Initializes and exposes the application's local Hive storage.
///
/// The application stores serialized maps rather than Hive-specific model
/// objects. This keeps the domain models independent from the database and
/// makes future migrations or a remote data source much easier.
class LocalStorage {
  const LocalStorage._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _initialized = true;
  }

  static Future<Box<dynamic>> openBox(String name) async {
    await initialize();
    if (Hive.isBoxOpen(name)) {
      return Hive.box<dynamic>(name);
    }
    return Hive.openBox<dynamic>(name);
  }

  static Future<void> close() async {
    if (!_initialized) return;
    await Hive.close();
    _initialized = false;
  }
}
