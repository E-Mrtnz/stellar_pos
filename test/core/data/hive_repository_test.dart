import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

class _TestEntity implements SyncableEntity {
  _TestEntity(this.id, this.value);

  @override
  final String id;
  final String value;

  @override
  final metadata = SyncMetadata(
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'value': value,
        'metadata': metadata.toMap(),
      };
}

class _FakeLocalDataSource implements LocalDataSource<_TestEntity> {
  final Map<String, _TestEntity> values = {};

  @override
  Future<List<_TestEntity>> getAll() async => values.values.toList();

  @override
  Future<_TestEntity?> getById(String id) async => values[id];

  @override
  Future<void> save(_TestEntity entity) async => values[entity.id] = entity;

  @override
  Future<void> delete(String id) async => values.remove(id);
}

void main() {
  test('repository delegates CRUD operations to its local data source', () async {
    final source = _FakeLocalDataSource();
    final repository = HiveRepository<_TestEntity>(source);
    final entity = _TestEntity('1', 'first');

    await repository.save(entity);
    expect(await repository.getById('1'), same(entity));
    expect(await repository.getAll(), [entity]);

    await repository.delete('1');
    expect(await repository.getById('1'), isNull);
  });
}
