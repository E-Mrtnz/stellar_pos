import 'package:hive_ce/hive_ce.dart';

import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Hive-backed data source that stores entities as serialized maps.
///
/// No domain model needs to extend a Hive class or know about Hive. The
/// serializer/deserializer functions keep persistence concerns in the data
/// layer.
class HiveDataSource<T extends SyncableEntity> implements LocalDataSource<T> {
  HiveDataSource({
    required this.boxName,
    required this.fromMap,
  });

  final String boxName;
  final T Function(Map<String, dynamic> map) fromMap;

  Future<Box<dynamic>> get _box => LocalStorage.openBox(boxName);

  @override
  Future<List<T>> getAll() async {
    final box = await _box;
    return box.values
        .whereType<Map>()
        .map((value) => fromMap(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  @override
  Future<T?> getById(String id) async {
    final box = await _box;
    final value = box.get(id);
    if (value is! Map) return null;
    return fromMap(Map<String, dynamic>.from(value));
  }

  @override
  Future<void> save(T entity) async {
    final box = await _box;
    await box.put(entity.id, entity.toMap());
  }

  @override
  Future<void> delete(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
