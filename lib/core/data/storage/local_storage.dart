import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Initializes and exposes the application's local Hive storage.
///
/// The application stores serialized maps rather than Hive-specific model
/// objects. This keeps the domain models independent from the database and
/// makes future migrations or a remote data source much easier.
class LocalStorage {
  const LocalStorage._();

  static bool _initialized = false;
  static final Set<String> _openBoxNames = <String>{};

  static Future<void> initialize() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _initialized = true;
  }

  static Future<Box<dynamic>> openBox(String name) async {
    await initialize();
    if (Hive.isBoxOpen(name)) {
      _openBoxNames.add(name);
      return Hive.box<dynamic>(name);
    }
    final box = await Hive.openBox<dynamic>(name);
    _openBoxNames.add(name);
    return box;
  }

  static Future<void> flush() async {
    if (!_initialized) return;
    for (final name in _openBoxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<dynamic>(name).flush();
      }
    }
  }

  static Future<String> databaseDirectoryPath() async {
    await initialize();
    final box = await Hive.openBox<dynamic>('__storage_metadata');
    final path = box.path;
    await box.close();
    _openBoxNames.remove('__storage_metadata');
    if (path == null || path.isEmpty) {
      throw StateError('No se pudo determinar la ruta de almacenamiento de Hive.');
    }
    return path.substring(0, path.lastIndexOf('/'));
  }

  static Future<void> close() async {
    if (!_initialized) return;
    await Hive.close();
    _openBoxNames.clear();
    _initialized = false;
  }
}
