import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/data/repositories/in_memory_repository.dart';
import 'package:stellar_pos/core/models/client.dart';

void main() {
  test('stores, reads and replaces entities by id', () async {
    final repository = InMemoryRepository<Client>();
    final first = Client(id: 'c1', name: 'Ana', phone: '111');
    final replacement = Client(id: 'c1', name: 'Ana Updated', phone: '222');

    await repository.save(first);
    expect(await repository.getById('c1'), same(first));

    await repository.save(replacement);
    expect(await repository.getById('c1'), same(replacement));
    expect((await repository.getAll()).length, 1);
  });

  test('returns an immutable snapshot and deletes by id', () async {
    final repository = InMemoryRepository<Client>();
    await repository.save(Client(id: 'c1', name: 'Ana', phone: '111'));

    final all = await repository.getAll();
    expect(all, hasLength(1));
    expect(() => all.clear(), throwsUnsupportedError);

    await repository.delete('c1');
    expect(await repository.getById('c1'), isNull);
    expect(await repository.getAll(), isEmpty);
  });
}
