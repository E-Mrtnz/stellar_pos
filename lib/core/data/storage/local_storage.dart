import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

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
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<void> close() async {
    if (!_initialized) return;
    await Hive.close();
    _openBoxNames.clear();
    _initialized = false;
  }
}
