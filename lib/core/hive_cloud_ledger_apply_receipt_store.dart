import 'package:hive_ce/hive_ce.dart';
import 'package:stellar_pos/core/cloud_ledger_remote_applier.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Hive-backed durable receipts for remotely applied ledger events.
///
/// Call [open] before giving this store to [DurableCloudLedgerRemoteApplier]
/// so existing receipts are loaded before the first page is processed.
class HiveCloudLedgerApplyReceiptStore
    implements CloudLedgerApplyReceiptStore {
  HiveCloudLedgerApplyReceiptStore._(this.boxName, this._box) {
    _refreshCache();
  }

  static Future<HiveCloudLedgerApplyReceiptStore> open({
    String boxName = 'cloud_ledger_apply_receipts',
  }) async {
    final box = await LocalStorage.openBox(boxName);
    return HiveCloudLedgerApplyReceiptStore._(boxName, box);
  }

  final String boxName;
  final Box<dynamic> _box;
  final Map<String, Object?> _cache = <String, Object?>{};

  void _refreshCache() {
    _cache
      ..clear()
      ..addAll(<String, Object?>{
        for (final key in _box.keys)
          if (key is String) key: _box.get(key) as Object?,
      });
  }

  @override
  Object? get(String eventId) => _cache[eventId];

  @override
  Future<void> put(String eventId, Object value) async {
    if (eventId.trim().isEmpty || eventId.contains('/')) {
      throw ArgumentError.value(eventId, 'eventId', 'Invalid receipt key.');
    }
    await _box.put(eventId, value);
    _cache[eventId] = value;
  }

  @override
  Future<void> flush() async {
    await _box.flush();
    _refreshCache();
  }
}
