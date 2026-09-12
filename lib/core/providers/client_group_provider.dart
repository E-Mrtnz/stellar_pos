import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/data/repositories/client_group_repository.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/client_group.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class ClientGroupProvider extends ChangeNotifier {
  final Repository<ClientGroup> _repository;
  final List<ClientGroup> _groups = [];
  Future<void>? _loadFuture;
  bool _loaded = false;

  ClientGroupProvider({Repository<ClientGroup>? repository})
      : _repository = repository ?? ClientGroupRepository();

  List<ClientGroup> get groups => List.unmodifiable(_groups);

  ClientGroup? groupForClient(String clientId) {
    for (final group in _groups) {
      if (group.clientIds.contains(clientId)) return group;
    }
    return null;
  }

  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadFromRepository();
    _loadFuture = future;
    return future;
  }

  bool addGroup(String name, List<String> clientIds) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || _hasName(normalizedName)) return false;
    final normalizedIds = _normalizeClientIds(clientIds);
    if (normalizedIds.isEmpty) return false;

    final group = ClientGroup(
      id: IdGenerator.newId(),
      name: normalizedName,
      clientIds: _withoutExistingMemberships(normalizedIds),
    );
    if (group.clientIds.isEmpty) return false;
    _groups.add(group);
    _persist(group);
    notifyListeners();
    return true;
  }

  bool updateGroup(String groupId, String name, List<String> clientIds) {
    final normalizedName = name.trim();
    final index = _groups.indexWhere((group) => group.id == groupId);
    if (index < 0 || normalizedName.isEmpty || _hasName(normalizedName, excludingId: groupId)) {
      return false;
    }

    final normalizedIds = _normalizeClientIds(clientIds);
    final group = ClientGroup(
      id: groupId,
      name: normalizedName,
      clientIds: _withoutExistingMemberships(normalizedIds, excludingId: groupId),
      metadata: _groups[index].metadata.touch(),
    );
    _groups[index] = group;
    _persist(group);
    notifyListeners();
    return true;
  }

  bool removeGroup(String groupId) {
    final index = _groups.indexWhere((group) => group.id == groupId);
    if (index < 0) return false;
    _groups.removeAt(index);
    unawaited(_repository.delete(groupId).catchError((_) {}));
    notifyListeners();
    return true;
  }

  List<String> availableClientIds(Iterable<String> clientIds, {String? excludingGroupId}) {
    final result = <String>[];
    for (final clientId in clientIds) {
      if (clientId.trim().isEmpty) continue;
      if (_withoutExistingMemberships([clientId], excludingId: excludingGroupId).contains(clientId)) {
        result.add(clientId);
      }
    }
    return result;
  }

  Future<void> _loadFromRepository() async {
    final stored = await _repository.getAll();
    final byId = <String, ClientGroup>{for (final group in _groups) group.id: group};
    for (final group in stored) {
      byId.putIfAbsent(group.id, () => group);
    }
    _groups
      ..clear()
      ..addAll(byId.values);
    _loaded = true;
    if (stored.isNotEmpty) notifyListeners();
  }

  bool _hasName(String name, {String? excludingId}) {
    final normalized = name.toLowerCase();
    return _groups.any((group) =>
        group.id != excludingId && group.name.trim().toLowerCase() == normalized);
  }

  List<String> _normalizeClientIds(Iterable<String> ids) => ids
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  List<String> _withoutExistingMemberships(
    Iterable<String> ids, {
    String? excludingId,
  }) {
    final occupied = <String>{};
    for (final group in _groups) {
      if (group.id == excludingId) continue;
      occupied.addAll(group.clientIds);
    }
    return ids.where((id) => !occupied.contains(id)).toList();
  }

  void _persist(ClientGroup group) {
    unawaited(_repository.save(group).catchError((_) {}));
  }
}
